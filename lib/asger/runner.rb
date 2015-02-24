require 'logger'
require 'aws-sdk'
require 'hashie'

require 'asger/task'

module Asger
  class Runner
    # @param logger [Logger] the logger for Asger to use
    # @param sqs_client [Aws::SQS::Client] the SQS client to use for polling
    # @param ec2_client [Aws::EC2::Client] the EC2 client to use to get instance information
    # @param queue_url [String] the queue URL to poll
    # @param parameters [Hash] a hash of parameters to pass to {Task}s
    # @param task_files [Array<String>] list of file paths to load as {Task}s
    def initialize(logger, sqs_client, ec2_client, queue_url, parameters, task_files)
      @logger = logger
      @sqs_client = sqs_client
      @ec2_client = ec2_client
      @ec2_resource_client = Aws::EC2::Resource.new(client: @ec2_client)
      @queue_url = queue_url
      @parameters = Hashie::Mash.new(parameters)
      @tasks = task_files.map { |tf| Task.from_file(@logger, tf) }
    end


    def step()
      messages = @sqs_client.receive_message(queue_url: @queue_url)[:messages]
      @logger.debug "Received #{messages.length} messages."
      messages.each do |msg|
        notification = JSON.parse(JSON.parse(msg[:body])["Message"])
        if notification["Event"] != nil
          case notification["Event"].gsub("autoscaling:", "")
            when "EC2_INSTANCE_LAUNCH"
              instance_id = notification["EC2InstanceId"]
              @logger.info "Instance launched: #{instance_id}"

              instance = @ec2_resource_client.instance(instance_id)
              @tasks.each do |task|
                task.invoke_up(instance, @parameters)
              end

              delete_message(msg)
            when "EC2_INSTANCE_LAUNCH_ERROR"
              @logger.warn "Instance launch error received."
              delete_message(msg)
            when "EC2_INSTANCE_TERMINATE"
              instance_id = notification["EC2InstanceId"]
              @logger.info "Instance terminated: #{instance_id}"

              @tasks.reverse.each do |task|
                task.invoke_down(instance_id, @parameters)
              end
              delete_message(msg)
            when "EC2_INSTANCE_TERMINATE_ERROR"
              @logger.warn "Instance terminate error received."
              delete_message(msg)
            when "TEST_NOTIFICATION"
              @logger.debug "Found test notification in queue."
            else
              @logger.debug "Unrecognized notification '#{notification["Event"]}', ignoring."
          end
        end
      end
    end

    private
    def delete_message(msg)
      @sqs_client.delete_message(queue_url: @queue_url, receipt_handle: msg[:receipt_handle])
    end
  end
end