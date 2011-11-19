require 'logger'
require 'fiber'
require 'fileutils'

module VCAP end
module VCAP::EMRun
  class << self
    CLOSE_FDS_PATH = File.expand_path("../close_fds", __FILE__)

    def init(logger = nil)
      @logger = logger || Logger.new(STDOUT)
    end

    def run_restricted(run_dir, user, base_cmd)
      user_name = user[:user_name]
      uid = user[:uid]

      close_fds_dst = File.join(run_dir, 'close_fds')
      FileUtils.cp(CLOSE_FDS_PATH, close_fds_dst)
      FileUtils.chmod(0500, close_fds_dst)
      FileUtils.chown(uid, nil, close_fds_dst)

      #XXX resource limits would be nice.

      run_action = proc do |process|
        process.send_data("cd #{run_dir}\n")
        process.send_data("ruby ./close_fds true #{base_cmd} 2>&1\n")
        process.send_data("exit\n")
      end

      f = Fiber.current
      exit_action = proc do |output, status|
        if status.exitstatus != 0
          @logger.debug("EM.system failed with: #{output}")
        else
          @logger.debug("completed with: #{output}")
        end
        f.resume([output, status.exitstatus])
      end

      sh_command = "env -i su -s /bin/sh #{user_name}"
      EM.system(sh_command, run_action, exit_action)
      Fiber.yield
    end

    def run(cmd, expected_exit_status = 0)
      f = Fiber.current
      EM.system("#{cmd} 2>&1") { |output, status|
        if status.exitstatus != expected_exit_status
          @logger.error("run (#{cmd}) expected #{expected_exit_status} saw #{status.exitstatus}")
          @logger.error("run output: #{output}")
        end
        f.resume([output, status.exitstatus])
      }
      Fiber.yield
    end

  end
end


