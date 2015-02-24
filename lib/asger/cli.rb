require 'logger'
require 'json'
require 'yaml'
require 'trollop'

require 'aws-sdk'

require 'asger/runner'

module Asger
  # Command line functionality for Asger.
  module CLI
    # Entry point called from `bin/asger`.
    def self.main()
      opts = Trollop::options do
        opt :task_file,       "path to a task (Ruby file; pass in order of execution)",
                              :type => :string, :multi => true
        opt :parameter_file,  "path to a params file (YAML or JSON; later files override earlier ones)",
                              :type => :string, :multi => true
        opt :queue_url,       "URL of the SQS queue to read from",
                              :type => :string
        opt :pause_time,      "Time (in seconds) to pause between polls.",
                              :default => 0
        opt :verbose,         "enables verbose logging",
                              :default => false
        opt :die_on_error,    "Terminates if an exception is thrown within the task runner.",
                              :default => true

        opt :aws_logging,     "Provides the Asger logger to AWS (use for deep debugging).", :default => false

        opt :shared_credentials, "Tells Asger to use shared credentials from '~/.aws/credentials'.", :type => :string
      end

      logger = Logger.new($stderr)
      logger.info "Initializing Asger."

      logger.level = opts[:verbose] ? Logger::DEBUG : Logger::INFO

      if !opts[:queue_url]
        logger.error "--queue-url is required."
        exit(1)
      end
      logger.warn "No tasks configured; Asger will run, but won't do much." unless !opts[:task_file]

      param_files = 
        opts[:parameter_file].map do |pf|
          logger.debug "Parsing parameter file '#{pf}'."
          case File.extname(pf)
            when ".json"
              JSON.parse(File.read(pf))
            when ".yaml"
              YAML.parse(File.read(pf))
            else
              raise "Unrecognized parameter file: '#{pf}'."
          end
        end

      parameters = {}
      param_files.each { |p| parameters.deep_merge!(p) }

      credentials = nil
      if opts[:shared_credentials]
        logger.info "Using shared credentials '#{opts[:shared_credentials]}'."
        credentials = Aws::SharedCredentials.new(profile_name: opts[:shared_credentials])
      end

      aws_logger = opts[:aws_logging] ? logger : nil
      sqs_client = Aws::SQS::Client.new(logger: aws_logger, credentials: credentials)
      ec2_client = Aws::EC2::Client.new(logger: aws_logger, credentials: credentials)

      runner = Runner.new(logger, sqs_client, ec2_client, opts[:queue_url], parameters, opts[:task_file])

      loop do
        begin
          runner.step()
        rescue StandardError => err
          logger.error "Encountered an error."
          logger.error "#{err.class.name}: #{err.message}"
          err.backtrace.each { |bt| logger.error bt }

          if opts[:die_on_error]
            raise err
          end
        end
        sleep opts[:pause_time] unless opts[:pause_time] == 0
      end
    end
  end
end