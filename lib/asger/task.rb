module Asger
  # A `Task` is a wrapper around an `up` and a `down` function. Up functions
  # are called when an auto-scaling group adds an instance, and Asger retrieves
  # the instance data for the task. Down functions are called when an
  # auto-scaling group downs an instance, and Asger passes along only the
  # instance ID (because it's all we've got).
  class Task
    attr_reader :logger

    def initialize(logger, code, filename = "unknown_file.rb")
      @logger = logger
      @name = File.basename(filename)
      instance_eval(code, filename, 1)
    end

    def invoke_up(instance, parameters)
      if @up_proc
        logger.debug "Invoking up for '#{@name}'..."
        @up_proc.call(instance, parameters)
        logger.debug "Up invoked for '#{@name}'..."
      end
    end

    def invoke_down(instance_id, parameters)
      if @up_proc
        logger.debug "Invoking down for '#{@name}'..."
        @down_proc.call(instance_id, parameters)
        logger.debug "Down invoked for '#{@name}'..."
      end
    end

    def self.from_file(logger, file)
      Task.new(logger, File.read(file), file)
    end

    private
    # Defines an 'up' function.
    # @yield [instance, parameters]
    # @yieldparam instance [Aws::EC2::Instance] the instance that has been created
    # @yieldparam parameters [Hash] the parameters passed in to Asger
    def up(&block)
      @up_proc = block
    end

    # Defines a 'down' function.
    # @yield [instance_id, parameters]
    # @yieldparam instance_id [String the ID of the recently terminated instance
    # @yieldparam parameters [Hash] the parameters passed in to Asger
    def down(&block)
      @down_proc = block
    end
  end
end