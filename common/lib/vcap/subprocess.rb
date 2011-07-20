require 'open3'

module VCAP
  class SubprocessError < StandardError
    attr_reader :command, :exit_status, :stdout, :stderr

    def initialize(command, stdout, stderr, exit_status)
      @command     = command
      @exit_status = exit_status
      @stdout      = stdout
      @stderr      = stderr
    end

    def to_s
      "ERROR: Command '#{@command}' exited with status '#{exit_status.to_i}'"
    end
  end

  # Utility class providing:
  #   - Ability to capture stdout/stderr of a command
  #   - Exceptions when commands fail (useful for running a chain of commands)
  #   - Easier integration with unit tests.
  class Subprocess
    def self.run(*args)
      VCAP::Subprocess.new.run(*args)
    end

    def run(command, expected_exit_status=0)
      result = Open3.capture3(command)

      unless result[2] == expected_exit_status
        raise SubprocessError.new(command, *result)
      end

      result
    end

  end

end
