require 'posix-spawn'

module VCAP
  class SubprocessError < StandardError; end

  # Command exited with unexpected status code
  class SubprocessStatusError < SubprocessError
    attr_reader :command, :status, :stdout, :stderr

    def initialize(command, stdout, stderr, status)
      @command     = command
      @status      = status
      @stdout      = stdout
      @stderr      = stderr
    end

    def to_s
      "ERROR: Command '#{@command}' exited with status '#{status.exitstatus}'"
    end
  end

  # Command ran longer than allowed
  class SubprocessTimeoutError < SubprocessError
    attr_reader :command, :timeout, :stdout, :stderr

    def initialize(timeout, command, stdout, stderr)
      @command = command
      @timeout = timeout
      @stdout  = stdout
      @stderr  = stderr
    end

    def to_s
      "ERROR: Command '#{@command}' timed out"
    end
  end

  # Failure reading from stdin/stdout
  class SubprocessReadError < SubprocessError
    attr_reader :command, :stdout, :stderr

    def initialize(failed_iostr, command, stdout, stderr)
      @failed_iostr = failed_iostr
      @command = command
      @stdout  = stdout
      @stderr  = stderr
    end

    def to_s
      "ERROR: Failed reading from #{@failed_iostr} while executing '#{@command}'"
    end
  end

  # Utility class providing:
  #   - Ability to capture stdout/stderr of a command
  #   - Exceptions when commands fail (useful for running a chain of commands)
  #   - Easier integration with unit tests.
  class Subprocess
    READ_SIZE = 4096

    def self.run(*args)
      VCAP::Subprocess.new.run(*args)
    end

    # Runs the supplied command in a subshell.
    #
    # @param  command               String   The command to be run
    # @param  expected_exit_status  Integer  The expected exit status of the command in [0, 255]
    # @param  timeout               Integer  How long the command should be allowed to run for
    #                                        nil indicates no timeout
    # @param  options               Hash     Options to be passed to Posix::Spawn
    #                                        See https://github.com/rtomayko/posix-spawn
    # @param  env                   Hash     Environment to be passed to Posix::Spawn
    #                                        See https://github.com/rtomayko/posix-spawn
    #
    # @raise  VCAP::SubprocessStatusError    Thrown if the exit status does not match the expected
    #                                        exit status.
    # @raise  VCAP::SubprocessTimeoutError   Thrown if a timeout occurs.
    # @raise  VCAP::SubprocessReadError      Thrown if there is an error reading from any of the pipes
    #                                        to the child.
    #
    # @return Array                          An array of [stdout, stderr, status]. Note that status
    #                                        is an instance of Process::Status.
    #
    def run(command, expected_exit_status=0, timeout=nil, options={}, env={})
      # We use a pipe to ourself to time out long running commands (if desired) as follows:
      #   1. Set up a pipe to ourselves
      #   2. Install a signal handler that writes to one end of our pipe on SIGCHLD
      #   3. Select on the read end of our pipe and check if our process exited
      sigchld_r, sigchld_w = IO.pipe
      prev_sigchld_handler = install_sigchld_handler(sigchld_w)

      start = Time.now.to_i
      child_pid, stdin, stdout, stderr = POSIX::Spawn.popen4(env, command, options)
      stdin.close

      # Used to look up the name of an io object when an errors occurs while
      # reading from it, as well as to look up the corresponding buffer to
      # append to.
      io_map = {
        stderr    => { :name => 'stderr',    :buf => '' },
        stdout    => { :name => 'stdout',    :buf => '' },
        sigchld_r => { :name => 'sigchld_r', :buf => '' },
        sigchld_w => { :name => 'sigchld_w', :buf => '' },
      }

      status = nil
      time_left   = timeout
      read_cands  = [stdout, stderr, sigchld_r]
      error_cands = read_cands.dup

      begin
        while read_cands.length > 0
          active_ios = IO.select(read_cands, nil, error_cands, time_left)

          # Check if timeout was hit
          if timeout
            time_left  = timeout - (Time.now.to_i - start)
            unless active_ios && (time_left > 0)
              raise VCAP::SubprocessTimeoutError.new(timeout,
                                                     command,
                                                     io_map[stdout][:buf],
                                                     io_map[stderr][:buf])
            end
          end

          # Read as much as we can from the readable ios before blocking
          for io in active_ios[0]
            begin
              io_map[io][:buf] << io.read_nonblock(READ_SIZE)
            rescue IO::WaitReadable
              # Reading would block, so put ourselves back on the loop
            rescue EOFError
              # Pipe has no more data, remove it from the readable/error set
              # NB: We cannot break from the loop here, as the other pipes may have data to be read
              read_cands.delete(io)
              error_cands.delete(io)
            end

            # Our signal handler notified us that >= 1 children have exited;
            # check if our child has exited.
            if (io == sigchld_r) && Process.waitpid(child_pid, Process::WNOHANG)
              status = $?
              read_cands.delete(sigchld_r)
              error_cands.delete(sigchld_r)
            end
          end

          # Error reading from one or more pipes.
          unless active_ios[2].empty?
            io_names = active_ios[2].map {|io| io_map[io][:name] }
            raise SubprocessReadError.new(io_names.join(', '),
                                          command,
                                          io_map[stdout][:buf],
                                          io_map[stderr][:buf])
          end
        end

      rescue
        # A timeout or an error occurred while reading from one or more pipes.
        # Kill the process if we haven't reaped its exit status already.
        kill_pid(child_pid) unless status
        raise

      ensure
        # Make sure we reap the child's exit status, close our fds, and restore
        # the previous SIGCHLD handler
        unless status
          Process.waitpid(child_pid)
          status = $?
        end
        io_map.each_key {|io| io.close unless io.closed? }
        trap('CLD') { prev_sigchld_handler.call } if prev_sigchld_handler
      end

      unless status.exitstatus == expected_exit_status
        raise SubprocessStatusError.new(command,
                                        io_map[stdout][:buf],
                                        io_map[stderr][:buf],
                                        status)
      end

      [io_map[stdout][:buf], io_map[stderr][:buf], status]
    end

    private

    def install_sigchld_handler(write_pipe)
      prev_handler = trap('CLD') do
        begin
          # Notify select loop that a child exited. We use a nonblocking write
          # to avoid writing more than PIPE_BUF bytes before we have the chance
          # to drain the pipe. Note that we only need to write a single byte
          # to detect if our child has exited.
          write_pipe.write_nonblock('x') unless write_pipe.closed?
        rescue IO::WaitWritable
        end
        prev_handler.call if prev_handler
      end
      prev_handler
    end

    def kill_pid(pid)
      begin
        Process.kill('KILL', pid)
      rescue Errno::ESRCH
      end
    end
  end

end
