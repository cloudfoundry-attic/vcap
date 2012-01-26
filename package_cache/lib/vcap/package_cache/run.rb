require 'tempfile'
require 'logger'

module Run
  class << self
    def init(logger)
      @logger = logger
      return if defined?(@secure_mode)
      if secure_mode_possible?
        @secure_mode = true
        logger.info("Running in secure mode...")
      else
        @secure_mode = false
        logger.warn("Running in INSECURE mode, see package_cache/INSTALL for more details")
      end
    end

    def secure_mode_possible?
      file = Tempfile.new('test')
      user_name = 'user-pool-package_cache-1'
      begin
        #can I run chown as root?
        run_sudo("chown #{user_name} #{file.path}")
        #can I run an arbitrary command as another user (needed to build)?
        run_sudo("-u #{user_name} ls")
      rescue
        @logger.info $!
        return false
      end
      true
    end

    def run_sudo(cmd, expected_result = 0)
      run_cmd("sudo -n #{cmd}", expected_result)
    end

    def chown(uid, gid, path)
      run_sudo("chown +#{uid}:+#{gid} #{path}") if @secure_mode
    end

    def run_cmd(cmd, expected_result = 0)
      cmd_str = "#{cmd} 2>&1"
      stdout = `#{cmd_str}`
      result = $?
      if result != expected_result
        raise "command #{cmd} failed with result #{result}, stdout #{stdout}, expected: #{expected_result}"
      end
      return stdout, result
    end

    def run_restricted(run_dir, user, cmd)
        #transfer_ownership(run_dir, user)
        chdir_cmd = "cd #{run_dir}"
        pass_ownership = "sudo chown -R +#{user[:uid]}:+#{user[:gid]} #{run_dir}"
        run_as_cmd = "sudo -n -u #{user[:user_name]} #{cmd}"
        recover_ownership = "sudo -n chown -R +#{Process.uid}:+#{Process.gid} #{run_dir}"
        if @secure_mode
          stdout, result = run_cmd(
            "#{chdir_cmd} ; #{pass_ownership}; #{run_as_cmd}; #{recover_ownership}")
        else
          stdout, result = run_cmd("cd #{run_dir}; #{cmd}")
        end
        return stdout, result
    end
  end
end

