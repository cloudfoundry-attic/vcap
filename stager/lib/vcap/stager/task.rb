require "nats/client"
require "uri"
require "yajl"

require "vcap/common"
require "vcap/logging"
require "vcap/stager/process_runner"
require "vcap/stager/task_error"
require "vcap/stager/task_logger"
require "vcap/stager/workspace"
require "vcap/staging/plugin/common"

module VCAP
  module Stager
  end
end

class VCAP::Stager::Task
  MAX_STAGING_DURATION = 120
  RUN_PLUGIN_PATH = File.expand_path('../../../../bin/run_plugin', __FILE__)

  attr_reader :task_id

  def initialize(request, opts = {})
    @nats         = opts[:nats] || NATS
    @task_id      = VCAP.secure_uuid
    @logger       = VCAP::Logging.logger("vcap.stager.task")
    @task_logger  = VCAP::Stager::TaskLogger.new(@logger)
    @request      = request
    @user_manager = opts[:secure_user_manager]
    @runner       = opts[:runner] || VCAP::Stager::ProcessRunner.new(@logger)
    @manifest_dir = opts[:manifest_root] || StagingPlugin::DEFAULT_MANIFEST_ROOT
    @ruby_path    = opts[:ruby_path] || "ruby"
    @run_plugin_path = opts[:run_plugin_path] || RUN_PLUGIN_PATH
    @max_staging_duration = opts[:max_staging_duration] || MAX_STAGING_DURATION
  end

  def log
    @task_logger.public_log
  end

  def enqueue(queue)
    @nats.publish("vcap.stager.#{queue}", Yajl::Encoder.encode(@request))
  end

  # Attempts to stage the application and upload the result to the specified
  # endpoint.
  def perform
    @logger.info("Starting task for request: #{@request}")

    @task_logger.info("Setting up temporary directories")
    workspace = VCAP::Stager::Workspace.create

    @task_logger.info("Downloading application")
    app_path = File.join(workspace.root_dir, "app.zip")
    download_app(app_path)

    @task_logger.info("Unpacking application")
    unpack_app(app_path, workspace.unstaged_dir)

    @task_logger.info("Staging application")
    stage_app(workspace.unstaged_dir, workspace.staged_dir, @task_logger)

    @task_logger.info("Creating droplet")
    droplet_path = File.join(workspace.root_dir, "droplet.tgz")
    create_droplet(workspace.staged_dir, droplet_path)

    @task_logger.info("Uploading droplet")
    upload_droplet(droplet_path)

    @task_logger.info("Done!")

    nil

  ensure
    workspace.destroy if workspace
  end

  private

  # NB: We use curl here to avoid putting Ruby's GC on the data path.
  def download_app(app_path)
    cfg_file = Tempfile.new("curl_dl_config")

    write_curl_config(@request["download_uri"], cfg_file.path,
                      "output" => app_path)

    # Show errors but not progress, fail on non-200
    res = @runner.run_logged("curl -s -S -f -K #{cfg_file.path}")

    unless res[:status].success?
      raise VCAP::Stager::TaskError.new("Failed downloading app")
    end

    nil
  ensure
    cfg_file.unlink if cfg_file
  end

  def unpack_app(packed_app_path, dst_dir)
    res = @runner.run_logged("unzip -q #{packed_app_path} -d #{dst_dir}")

    unless res[:status].success?
      raise VCAP::Stager::TaskError.new("Failed unpacking app")
    end
  end

  # Stages the application into the supplied directory.
  def stage_app(src_dir, dst_dir, task_logger)
    plugin_config = {
      "source_dir"   => src_dir,
      "dest_dir"     => dst_dir,
      "environment"  => @request["properties"],
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
           @request["properties"]["framework"],
           plugin_config_file.path].join(" ")

    res = @runner.run_logged(cmd,
                             :max_staging_duration => @max_staging_duration)

    capture_staging_log(dst_dir, task_logger)

    # Staging failed, log the error and abort
    unless res[:status].success?
      emsg = nil
      if res[:timed_out]
        emsg = "Staging timed out after #{@max_staging_duration} seconds."
      else
        emsg = "Staging plugin failed: #{res[:stdout]}"
      end

      task_logger.warn(emsg)

      raise VCAP::Stager::TaskError.new(emsg)
    end

    nil
  ensure
    plugin_config_file.unlink if plugin_config_file

    return_secure_user(secure_user) if secure_user
  end

  def create_droplet(staged_dir, droplet_path)
    cmd = ["cd", staged_dir, "&&", "COPYFILE_DISABLE=true",
           "tar", "-czf", droplet_path, "*"].join(" ")

    res = @runner.run_logged(cmd)

    unless res[:status].success?
      raise VCAP::Stager::TaskError.new("Failed creating droplet")
    end
  end

  def upload_droplet(droplet_path)
    cfg_file = Tempfile.new("curl_ul_config")

    write_curl_config(@request["upload_uri"], cfg_file.path,
                      "form" => "upload[droplet]=@#{droplet_path}")

    # Show errors but not progress, fail on non-200
    res = @runner.run_logged("curl -s -S -f -K #{cfg_file.path}")

    unless res[:status].success?
      raise VCAP::Stager::TaskError.new("Failed uploading droplet")
    end

    nil
  ensure
    cfg_file.unlink if cfg_file
  end

  # Writes out a curl config to the supplied path. This allows us to use
  # authenticated urls without potentially leaking them via the command line.
  #
  # @param [String]  url          The url being fetched/updated.
  # @param [String]  config_path  Where to write the config
  # @param [Hash]    opts         A list of key-value curl options. These will
  #                               be written to the config file as:
  #                               <key> = "<value>"\n
  #
  # @return nil
  def write_curl_config(url, config_path, opts = {})
    parsed_url = URI.parse(url)

    config = opts.dup

    if parsed_url.user
      config["user"] = [parsed_url.user, parsed_url.password].join(":")
      parsed_url.user = nil
      parsed_url.password = nil
    end

    config["url"] = parsed_url.to_s

    File.open(config_path, "w+") do |f|
      config.each do |k, v|
        f.write("#{k} = \"#{v}\"\n")
      end
    end

    nil
  end

  # Appends the staging log (if any) to the user visible log
  def capture_staging_log(staged_dir, task_logger)
    staging_log_path = File.join(staged_dir, "logs", "staging.log")

    return unless File.exist?(staging_log_path)

    File.open(staging_log_path, "r") do |sl|
      begin
        while line = sl.readline
          line.chomp!
          task_logger.info(line)
        end
      rescue EOFError
      end
    end

    nil
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
