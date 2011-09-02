$:.unshift(File.join(File.dirname(__FILE__)))
require 'vdebug'
module Run
  class << self
    def run_as(uid, cmd)
      pid = fork
      if pid # parent -- wait for subprocess to complete.
        Process.waitpid(pid)
        child_status = $?

        if child_status.exitstatus != 0
          pdebug("run_as: command #{cmd} exited non-zero status #{child_status.exitstatus}")
          nil
        else
          pdebug("run_as: exit success!")
        end
      else #child --  move, cleanup, do it!
        close_fds
        exec("sudo -u ##{uid} #{cmd}")
      end
    end

    def close_fds
      3.upto(get_max_open_fd) do |fd|
        begin
          IO.for_fd(fd, "r").close
        rescue
        end
      end
    end

    def get_max_open_fd
      max = 0

      dir = nil
      if File.directory?("/proc/self/fd/") # Linux
        dir = "/proc/self/fd/"
      elsif File.directory?("/dev/fd/") # Mac
        dir = "/dev/fd/"
      end

      if dir
        Dir.foreach(dir) do |entry|
          begin
            pid = Integer(entry)
            max = pid if pid > max
          rescue
          end
        end
      else
        max = 65535
      end

      max
    end
  end
end


