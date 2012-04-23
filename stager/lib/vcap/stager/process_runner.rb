module VCAP
  module Stager
  end
end

class VCAP::Stager::ProcessRunner
  MAX_READLEN = 1024 * 1024

  def initialize(logger)
    @logger = logger
  end

  # Runs a command and captures stdout/stderr/status
  #
  # @param [String] cmd  The command to run.
  # @param [Hash]   opts
  # @option opts [Integer] :timeout  How long the process is allowed to run for
  #
  # @return [Hash]  A hash with the following keys:
  #                 :stdout    => String
  #                 :stderr    => String
  #                 :timed_out => Boolean
  #                 :status    => Process::Status
  def run(cmd, opts = {})
    pipes = [IO.pipe, IO.pipe]

    child_pid = Process.spawn(cmd, :out => pipes[0][1], :err => pipes[1][1])

    # Only need the read side in parent
    pipes.each { |ios| ios[1].close }

    child_stdout, child_stderr = pipes[0][0], pipes[1][0]

    timeout = opts[:timeout] ? Float(opts[:timeout]) : nil

    # Holds data read thus far
    child_stdio_bufs = {
      child_stdout => "",
      child_stderr => "",
    }

    active = nil
    watched = child_stdio_bufs.keys
    start = Time.now

    while !watched.empty? &&
        (active = IO.select(watched, nil, watched, timeout))
      active.flatten.each do |io|
        begin
          child_stdio_bufs[io] << io.read_nonblock(MAX_READLEN)
        rescue IO::WaitReadable
          # Wait for more data
        rescue EOFError
          watched.delete(io)
        end
      end

      if timeout
        now = Time.now
        timeout -= now - start
        start = now
      end
    end

    ret = {
      :stdout    => child_stdio_bufs[child_stdout],
      :stderr    => child_stdio_bufs[child_stderr],
      :timed_out => active.nil?,
      :status    => nil,
    }

    Process.kill("KILL", child_pid) if ret[:timed_out]

    Process.waitpid(child_pid)

    ret[:status] = $?

    ret
  ensure
    pipes.each do |ios|
      ios.each { |io| io.close unless io.closed? }
    end
  end

  # Runs the supplied command and logs the exit status, stdout, and stderr.
  #
  # @see VCAP::Stager::ProcessRunner#run for a description of arguments and
  #      return value.
  def run_logged(cmd, opts = {})
    ret = run(cmd, opts)

    exitstatus = ret[:status].exitstatus
    @logger.debug("Command #{cmd} exited with status #{exitstatus}")
    @logger.debug("stdout: #{ret[:stdout]}")
    @logger.debug("stderr: #{ret[:stderr]}")

    ret
  end
end
