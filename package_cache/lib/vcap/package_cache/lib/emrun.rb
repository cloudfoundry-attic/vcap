require 'logger'
require 'fiber'

module VCAP end
module VCAP::EMRun
  class << self
    def init(logger)
      @logger = logger || Logger.new(STDOUT)
    end

    def run_restricted(run_dir, user, base_cmd)
      user_name = user[:user_name]
      uid = user[:uid]
      f = Fiber.current
      #the EM.system dance, you can't just concatenate all your commands.
      sh_command = "env -i su -s /bin/sh #{user_name}"
      close_fds_path = File.join(run_dir, 'close_fds')
      FileUtils.cp(File.expand_path("../../../../../bin/close_fds", __FILE__), close_fds_path)
      #XXX should change this to just read/execute instead of read/write/execute.
      #XXX would be nice to remove self deletion from close_fds, don't need it.
      FileUtils.chmod(0700, close_fds_path)
      FileUtils.chown(uid, nil, close_fds_path)

      run_action = proc do |process|
        process.send_data("cd #{run_dir}\n")
        process.send_data("ruby ./close_fds true #{base_cmd}\n")
        process.send_data("exit\n")
      end

      exit_action = proc do |output, status|
        if status.exitstatus != 0
          @logger.error("EM.system failed with: #{output}")
        else
          @logger.debug("completed with: #{output}")
        end
        f.resume
      end

      EM.system(sh_command, run_action, exit_action)
      Fiber.yield
    end

    def run(cmd, expected_exit_status = 0)
      f = Fiber.current
      EM.system(cmd) { |output, status|
        if status.exitstatus != expected_exit_status
          @logger.error("unexpected exit status on cmd #{cmd}")
        end
        f.resume
      }
      Fiber.yield
    end
  end
end


