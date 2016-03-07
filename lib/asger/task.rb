require 'asger/util'

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

    def invoke_init(parameters)
      if @init_proc
        logger.debug "Initializing for '#{@name}'..."
        @init_proc.call(parameters)
      else
        logger.debug "No init for '#{@name}'."
      end
    end

    def invoke_up(instance, asg, parameters)
      if @up_proc
        logger.debug "Invoking up for '#{@name}'..."
        @up_proc.call(instance, asg, parameters)
        logger.debug "Up invoked for '#{@name}'..."
      else
        logger.debug "No up for '#{@name}'."
      end
    end

    def invoke_down(instance_id, asg, parameters)
      if @down_proc
        logger.debug "Invoking down for '#{@name}'..."
        @down_proc.call(instance_id, asg, parameters)
        logger.debug "Down invoked for '#{@name}'..."
      else
        logger.debug "No down for '#{@name}'."
      end
    end

    def invoke_up_failed(asg, parameters)
      if @up_failed_proc
        logger.debug "Invoking up_failed for '#{@name}'..."
        @up_failed_proc.call(asg, parameters)
        logger.debug "up_failed invoked for '#{@name}'..."
      else
        logger.debug "No up_failed for '#{@name}'."
      end
    end

    def invoke_down_failed(instance_id, asg, parameters)
      if @down_failed_proc
        logger.debug "Invoking down_failed for '#{@name}'..."
        @down_failed_proc.call(instance_id, asg, parameters)
        logger.debug "down_failed invoked for '#{@name}'..."
      else
        logger.debug "No down_failed for '#{@name}'."
      end
    end

    def self.from_file(logger, file)
      Task.new(logger, File.read(file), file)
    end

    private
    # Defines an init function, which should set member vars. Raise and fail (which
    # will halt Asger before it does anything with the actual queue) if there's a
    # problem with the parameter set.
    #
    # @yield [parameters]
    # @yieldparam parameters [Hash] the parameters passed in to Asger
    def init(&block)
      @init_proc = block
    end

    # Defines an 'up' function, addressing `EC2_INSTANCE_LAUNCH`.
    # @yield [instance, parameters]
    # @yieldparam instance [Aws::EC2::Instance] the instance that has been created
    # @yieldparam asg [nil, Aws::AutoScaling::AutoScalingGroup] the ASG resource of the launched instance
    # @yieldparam parameters [Hash] the parameters passed in to Asger
    def up(&block)
      @up_proc = block
    end

    # Defines a 'down' function, addressing `EC2_INSTANCE_TERMINATE`.
    # @yield [instance_id, parameters]
    # @yieldparam instance_id [String] the ID of the recently terminated instance
    # @yieldparam asg [nil, Aws::AutoScaling::AutoScalingGroup] the ASG resource of the terminated instance
    # @yieldparam parameters [Hash] the parameters passed in to Asger
    def down(&block)
      @down_proc = block
    end

    # Defines an 'up_failed' function, addressing `EC2_INSTANCE_LAUNCH_ERROR`.
    # @yield [asg, parameters]
    # @yieldparam asg [nil, Aws::AutoScaling::AutoScalingGroup] the ASG resource of the failed instance
    # @yieldparam parameters [Hash] the parameters passed in to Asger
    def up_failed(&block)
      @up_failed_proc = block
    end

    # Defines an 'up_failed' function, addressing `EC2_INSTANCE_TERMINATE_ERROR`.
    # @yield [asg, parameters]
    # @yieldparam instance_id [String] the ID of the instance that failed to terminate
    # @yieldparam asg [nil, Aws::AutoScaling::AutoScalingGroup] the ASG resource of the failed instance
    # @yieldparam parameters [Hash] the parameters passed in to Asger
    def down_failed(&block)
      @down_failed_proc = block
    end
  end
end