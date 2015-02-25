module Asger
  module Util

    def self.run_command(subcommand_name, command, directory = ROOT, hide_cmd = false, hide_stdout = false)
      LOGGER.info "[#{subcommand_name}] => #{command}" unless hide_cmd

      lines = []

      Dir.chdir(directory) do
        # TODO: this should probably raise on nonzero.
        Open3::popen3(command) do |stdin, stdout, stderr, wait_thr|
          stdout.read.split("\n").each do |line|
            lines << line 
            LOGGER.debug "[#{subcommand_name}] O: #{line}" unless hide_stdout
          end
          stderr.read.split("\n").each do |line|
            LOGGER.debug "[#{subcommand_name}] E: #{line}"
          end

          if wait_thr.exited? || wait_thr.stopped?
            return [ wait_thr.exitstatus, lines.join("\n") ]
          end
        end
      end

      raise "should never reach here!"
    end

  end
end