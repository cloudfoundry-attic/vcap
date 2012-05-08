require "vcap/stager/plugin_runner/base"

require "vcap/logging"
require "vcap/staging/plugin/common"

class VCAP::Stager::PluginRunner::UserBased < VCAP::Stager::PluginRunner::Base
  RUN_PLUGIN_PATH = File.expand_path('../../../../../bin/run_plugin', __FILE__)

  def initialize(opts = {})
    @logger = VCAP::Logging.logger("vcap.stager.plugin_runner.user_based")
    @manifest_dir = opts[:manifest_root] || StagingPlugin::DEFAULT_MANIFEST_ROOT
    @ruby_path    = opts[:ruby_path] || "ruby"
    @runner = opts[:runner] || VCAP::Stager::ProcessRunner.new(@logger)
    @run_plugin_path = opts[:run_plugin_path] || RUN_PLUGIN_PATH
    @user_manager = opts[:user_manager]
  end

  def stage(properties, src_dir, dst_dir, opts = {})
    plugin_config = {
      "source_dir"   => src_dir,
      "dest_dir"     => dst_dir,
      "environment"  => properties,
      "manifest_dir" => @manifest_dir,
    }

    secure_user = nil

    if @user_manager
      secure_user = @user_manager.checkout_user

      plugin_config["secure_user"] = {
        "uid" => secure_user[:uid],
        "gid" => secure_user[:gid],
      }
    end

    plugin_config_file = Tempfile.new("plugin_config")
    StagingPlugin::Config.to_file(plugin_config, plugin_config_file.path)

    cmd = [@ruby_path, @run_plugin_path,
           properties["framework"],
           plugin_config_file.path].join(" ")

    res = @runner.run_logged(cmd, :timeout => opts[:timeout])

    ret = { :log => "" }

    log_path = File.join(dst_dir, "logs", "staging.log")
    ret[:log] = File.read(log_path) if File.exist?(log_path)

    # Staging failed, log the error and abort
    unless res[:status].success?
      if res[:timed_out]
        ret[:error] = "Staging timed out after #{opts[:timeout]} seconds."
      else
        ret[:error] = "Staging plugin failed: #{res[:stderr]}"
      end
    end

    ret

  ensure
    return_secure_user(secure_user) if secure_user

    plugin_config_file.unlink if plugin_config_file
  end

  # Returns a secure user to the pool and kills any processes belonging to
  # said user.
  def return_secure_user(user)
    @logger.info("Returning user #{user} to pool")

    cmd = "sudo -u '##{user[:uid]}' pkill -9 -U #{user[:uid]}"
    kres = @runner.run_logged(cmd)
    # 0 : >=1 process matched
    # 1 : no process matched
    # 2 : error
    if kres[:status].exitstatus < 2
      @user_manager.return_user(user)

      true
    else
      @logger.warn("Failed killing processes for user #{user}")

      false
    end
  end
end
