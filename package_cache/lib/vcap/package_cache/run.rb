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

    def chown_r(uid, gid, path)
      run_sudo("chown -R +#{uid}:+#{gid} #{path}") if @secure_mode
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

    def transfer_ownership(path, user)
      chown_r(user[:uid], user[:gid], path)
    end

    def recover_ownership(path)
      chown_r(Process.uid, Process.gid, path)
    end

    def run_restricted(run_dir, user, cmd)
      Dir.chdir(run_dir) {
        transfer_ownership(run_dir, user)
        if @secure_mode
          stdout, result = run_sudo("-u #{user[:user_name]} #{cmd}")
        else
          stdout, result = run_cmd(cmd)
        end
        recover_ownership(run_dir)
        return stdout, result
      }
    end
  end
end

