require 'logger'
require 'json'
require 'yaml'
require 'trollop'

require 'aws-sdk'
require 'active_support'

require 'asger/runner'

module Asger
  # Command line functionality for Asger.
  module CLI
    # Entry point called from `bin/asger`.
    def self.main()
      opts = Trollop::options do
        opt :task_file,       "path to a task (Ruby file; pass in order of execution; % refers to the stock_scripts directory)",
                              :type => :string, :multi => true
        opt :parameter_file,  "path to a params file (YAML or JSON; later files override earlier ones)",
                              :type => :string, :multi => true
        opt :queue_url,       "URL of the SQS queue to read from",
                              :type => :string
        opt :verbose,         "enables verbose logging",
                              :default => false
        opt :die_on_error,    "Terminates if an exception is thrown within the task runner.",
                              :default => true

        opt :delete_messages, 'Delete messages from the SQS queue after processing (off is useful for development).',
                              :default => true

        opt :aws_logging,     "Provides the Asger logger to AWS (use for deep debugging).", :default => false

        opt :shared_credentials, "Tells Asger to use shared credentials from '~/.aws/credentials'.", :type => :string
        opt :iam,             "Tells Asger to use IAM credentials.", :default => false
        opt :region,          'Specifies an AWS region.', :type => :string
      end

      logger = Logger.new($stderr)
      logger.info "Initializing Asger."

      logger.level = opts[:verbose] ? Logger::DEBUG : Logger::INFO

      if !opts[:queue_url]
        logger.error "--queue-url is required."
        exit(1)
      end
      if opts[:shared_credentials] && opts[:iam]
        logger.error "Only one of --shared-credentials and --iam can be used at a time."
        exit(1)
      end

      logger.warn "No tasks configured; Asger will run, but won't do much." \
        unless (opts[:task_file] && !opts[:task_file].empty?)

      param_files =
        opts[:parameter_file].map do |pf|
          logger.debug "Parsing parameter file '#{pf}'."
          case File.extname(pf)
            when ".json"
              JSON.parse(File.read(pf))
            when ".yaml"
              YAML.load(File.read(pf))
            else
              raise "Unrecognized parameter file: '#{pf}'."
          end
        end

      parameters = {}
      param_files.each { |p| parameters.deep_merge!(p) }

      credentials =
        if opts[:shared_credentials]
          logger.info "Using shared credentials '#{opts[:shared_credentials]}'."
          Aws::SharedCredentials.new(profile_name: opts[:shared_credentials])
        elsif opts[:iam]
          Aws::InstanceProfileCredentials.new
        else
          raise "No credentials found. Use --shared-credentials or --iam."
        end

      aws_logger = opts[:aws_logging] ? logger : nil
      sqs_client = Aws::SQS::Client.new(logger: aws_logger,
        region: opts[:region], credentials: credentials)
      ec2_client = Aws::EC2::Client.new(logger: aws_logger,
        region: opts[:region], credentials: credentials)
      asg_client = Aws::AutoScaling::Client.new(logger: aws_logger,
        region: opts[:region], credentials: credentials)


      stock_scripts_dir = File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "stock_scripts"))
      task_files = opts[:task_file].map { |f| f.gsub("%", stock_scripts_dir)}

      logger.info "Using task files:"
      task_files.each { |tf| logger.info " - #{tf}" }
      runner = Runner.new(logger: logger, aws_logger: aws_logger,
                          region: opts[:region], credentials: credentials,
                          queue_url: opts[:queue_url],
                          parameters: parameters,
                          task_files: task_files,
                          no_delete_messages: !opts[:delete_messages])

      logger.info "Beginning poll loop."
      loop do
        begin
          runner.poll
        rescue StandardError => err
          logger.error "Encountered an error."
          logger.error "#{err.class.name}: #{err.message}"
          err.backtrace.each { |bt| logger.error bt }

          if opts[:die_on_error]
            raise err
          else
            logger.error "re-entering poll."
          end
        end
      end
    end
  end
end
