require 'open3'

module Asger
  module Util

    def self.run_command(subcommand_name, command, logger = nil, directory = nil)
      directory = directory || Dir.getwd()
      logger.info "[#{subcommand_name}] => #{command}" unless !logger

      lines = []

      Dir.chdir(directory) do
        # TODO: this should probably raise on nonzero.
        thread = Open3::popen3(command) do |stdin, stdout, stderr, wait_thr|
          stdout.read.split("\n").each do |line|
            lines << line 
            logger.debug "[#{subcommand_name}] O: #{line}" unless !logger
          end
          stderr.read.split("\n").each do |line|
            logger.debug "[#{subcommand_name}] E: #{line}" unless !logger
          end

          wait_thr
        end

        [ thread.value.exitstatus, lines.join("\n") ]
      end
    end

  end
end