require 'logger'
require 'aws-sdk'
require 'ice_nine'
require 'active_support/all'

require 'asger/task'

module Asger
  class Runner
    # @param logger [Logger] the logger for Asger to use
    # @param sqs_client [Aws::SQS::Client] the SQS client to use for polling
    # @param ec2_client [Aws::EC2::Client] the EC2 client to use to get instance information
    # @param asg_client [Aws::AutoScaling::Client] the ASG client to use to get ASG information
    # @param queue_url [String] the queue URL to poll
    # @param parameters [Hash] a hash of parameters to pass to {Task}s
    # @param task_files [Array<String>] list of file paths to load as {Task}s
    # @param no_delete_messages [TrueClass, FalseClass] if true, don't call sqs:DeleteMessage
    def initialize(logger:, aws_logger:, credentials:,
                   region:, queue_url:,
                   parameters:, task_files:, no_delete_messages:)
      @logger = logger
      @region = region
      @parameters = parameters.merge(
        region: region.freeze, credentials: credentials
      ).freeze

      @sqs_client = Aws::SQS::Client.new(logger: aws_logger,
        region: region, credentials: credentials)
      @ec2_client = Aws::EC2::Client.new(logger: aws_logger,
        region: region, credentials: credentials)
      @asg_client = Aws::AutoScaling::Client.new(logger: aws_logger,
        region: region, credentials: credentials)
      @ec2_resource_client = Aws::EC2::Resource.new(client: @ec2_client)
      @asg_resource_client = Aws::AutoScaling::Resource.new(client: @asg_client)
      @queue_url = queue_url
      @tasks = task_files.map { |tf| Task.from_file(@logger, tf) }
      @no_delete_messages = no_delete_messages

      @logger.info "#{@tasks.length} task(s) set up."
      @logger.warn('no_delete_messages is set; will not clear SQS messages!') \
        if @no_delete_messages

      @tasks.each { |t| t.invoke_init(@parameters) }
    end


    def poll()
      poller = Aws::SQS::QueuePoller.new(@queue_url, client: @sqs_client,
        max_number_of_messages: 10, skip_delete: true)

      poller.poll do |msgs|
        [ msgs ].flatten.each do |msg|
          notification = JSON.parse(JSON.parse(msg.body)["Message"])
          if notification["Event"] != nil
            asg = @asg_resource_client.group(notification['AutoScalingGroupName'])
            instance_id = notification["EC2InstanceId"]

            @logger.warn("ASG '#{asg}' has fired event, but does not exist - already cleaned up?") \
              unless asg.exists?

            case notification["Event"].gsub("autoscaling:", "")
            when "EC2_INSTANCE_LAUNCH"
              @logger.info "Instance launched in '#{asg.name}': #{instance_id}"

              instance = @ec2_resource_client.instance(instance_id)
              @tasks.each do |task|
                task.invoke_up(instance, asg, @parameters)
              end

              delete_message(msg) unless @no_delete_messages
            when "EC2_INSTANCE_LAUNCH_ERROR"
              @logger.warn "Instance failed to launch in '#{asg.name}'."

              @tasks.each do |task|
                task.invoke_up_failed(asg, @parameters)
              end

              delete_message(msg) unless @no_delete_messages
            when "EC2_INSTANCE_TERMINATE"
              @logger.info "Instance terminated in '#{asg.name}': #{instance_id}"

              @tasks.reverse_each do |task|
                task.invoke_down(instance_id, asg, @parameters)
              end

              delete_message(msg) unless @no_delete_messages
            when "EC2_INSTANCE_TERMINATE_ERROR"
              @logger.warn "Instance failed to terminate in '#{asg.name}': #{instance_id}"

              @tasks.reverse_each do |task|
                task.invoke_down_failed(instance_id, asg, @parameters)
              end
              delete_message(msg) unless @no_delete_messages
            when "TEST_NOTIFICATION"
              @logger.info "Found test notification in queue."
              delete_message(msg) unless @no_delete_messages
            else
              @logger.debug "Unrecognized notification '#{notification["Event"]}', ignoring."
            end
          end
        end
      end
    end

    private

    def delete_message(msg)
      @logger.debug "Deleting message '#{msg[:receipt_handle]}'"
      @sqs_client.delete_message(queue_url: @queue_url, receipt_handle: msg[:receipt_handle])
    end
  end
end