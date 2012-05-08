require "uri"
require "yajl"

require "vcap/common"
require "vcap/logging"
require "vcap/stager/process_runner"
require "vcap/stager/task_error"
require "vcap/stager/task_logger"
require "vcap/stager/workspace"

module VCAP
  module Stager
  end
end

class VCAP::Stager::Task
  MAX_STAGING_DURATION = 120

  attr_reader :task_id

  def initialize(request, plugin_runner, opts = {})
    @task_id       = VCAP.secure_uuid
    @logger        = VCAP::Logging.logger("vcap.stager.task")
    @task_logger   = VCAP::Stager::TaskLogger.new(@logger)
    @request       = request
    @plugin_runner = plugin_runner
    @runner        = opts[:runner] || VCAP::Stager::ProcessRunner.new(@logger)
    @max_staging_duration = opts[:max_staging_duration] || MAX_STAGING_DURATION
  end

  def log
    @task_logger.public_log
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
    res = @plugin_runner.stage(@request["properties"],
                               workspace.unstaged_dir,
                               workspace.staged_dir,
                               :timeout => @max_staging_duration)

    @task_logger.info("Staging plugin log:")
    res[:log].split(/\n/).each { |l| @task_logger.info(l.chomp) }

    if res[:error]
      raise VCAP::Stager::TaskError.new(res[:error])
    end

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
    res = @runner.run_logged("env -u http_proxy -u https_proxy curl -s -S -f -K #{cfg_file.path}")

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
    res = @runner.run_logged("env -u http_proxy -u https_proxy curl -s -S -f -K #{cfg_file.path}")

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
end
