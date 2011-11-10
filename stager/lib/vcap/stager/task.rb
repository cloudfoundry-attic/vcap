require 'fiber'
require 'fileutils'
require 'nats/client'
require 'tmpdir'
require 'uri'
require 'yajl'

require 'vcap/common'
require 'vcap/logging'
require 'vcap/staging/plugin/common'

require 'vcap/stager/constants'
require 'vcap/stager/errors'
require 'vcap/stager/plugin_runner'

module VCAP
  module Stager
  end
end

class VCAP::Stager::Task
  DEFAULTS = {
    :nats                       => NATS,
    :manifest_dir               => StagingPlugin::DEFAULT_MANIFEST_ROOT,
    :max_staging_duration       => 120, # 2 min
    :download_app_helper_path   => File.join(VCAP::Stager::BIN_DIR, 'download_app'),
    :upload_droplet_helper_path => File.join(VCAP::Stager::BIN_DIR, 'upload_droplet'),
  }

  class << self
    def set_defaults(defaults={})
      DEFAULTS.update(defaults)
    end
  end

  attr_reader :task_id, :app_id, :result
  attr_accessor :user

  # @param  app_id        Integer Globally unique id for app
  # @param  props         Hash    App properties. Keys are
  #                                 :runtime     => Application runtime name
  #                                 :framework   => Application framework name
  #                                 :environment => Applications environment variables.
  #                                                 Hash of NAME => VALUE
  #                                 :services    => Services bound to app
  #                                 :resources   => Resource limits
  # @param  download_uri  String  Where the stager can fetch the zipped application from.
  # @param  upload_uri    String  Where the stager should PUT the gzipped droplet
  def initialize(app_id, props, download_uri, upload_uri, cc_info, response, opts={})
    @task_id      = VCAP.secure_uuid
    @app_id       = app_id
    @app_props    = props
    @download_uri = download_uri
    @upload_uri   = upload_uri
    @cc_info      = cc_info
    @response     = response

    @vcap_logger = VCAP::Logging.logger('vcap.stager.task')
    @nats                 = option(opts, :nats)
    @max_staging_duration = option(opts, :max_staging_duration)
    @run_plugin_path      = option(opts, :run_plugin_path)
    @ruby_path            = option(opts, :ruby_path)
    @manifest_dir         = option(opts, :manifest_dir)
    @tmpdir_base          = opts[:tmpdir]
    @user                 = opts[:user]
    @download_app_helper_path = option(opts, :download_app_helper_path)
    @upload_droplet_helper_path = option(opts, :upload_droplet_helper_path)
  end

  # Performs the staging task, calls the supplied callback upon completion.
  #
  # NB: We use a fiber internally to avoid descending into callback hell. This
  # method could easily end up looking like the following:
  #  create_staging_dirs do
  #    download_app do
  #      unzip_app do
  #        etc...
  #
  # @param  callback  Block  Block to be called when the task completes (upon both success
  #                          and failure). This will be called with an instance of VCAP::Stager::TaskResult
  def perform(&callback)
    Fiber.new do
      begin
        task_logger = VCAP::Stager::TaskLogger.new(@vcap_logger)
        task_logger.info("Starting staging operation")
        @vcap_logger.debug("app_id=#{@app_id}, properties=#{@app_props}")
        @vcap_logger.debug("download_uri=#{@download_uri} upload_uri=#{@upload_uri} cc_info=#{@cc_info}")

        task_logger.info("Setting up temporary directories")
        dirs = create_staging_dirs(@tmpdir_base)

        task_logger.info("Fetching application bits from the Cloud Controller")
        download_app(dirs[:unstaged], dirs[:base])

        task_logger.info("Staging application")
        if @app_props['plugins']
          run_plugins(dirs[:unstaged], dirs[:staged], dirs[:base])
        else
          run_staging_plugin(dirs[:unstaged], dirs[:staged], dirs[:base], task_logger)
        end

        task_logger.info("Uploading droplet")
        upload_droplet(dirs[:staged], dirs[:base])

        task_logger.info("Done!")
        complete_task(callback, task_logger.public_log)

      rescue VCAP::Stager::TaskError => te
        task_logger.error("Error: #{te}")
        complete_task(callback, task_logger.public_log, te.to_s)

      rescue => e
        @vcap_logger.error("Unrecoverable error: #{e}")
        @vcap_logger.error(e)
        raise e

      ensure
        EM.system("rm -rf #{dirs[:base]}") if dirs
      end

    end.resume
  end

  private

  def complete_task(callback, log, error=nil)
    @result = {
      :task_log => log,
      :error    => error,
    }
    @response.result = @result
    @nats.publish(@response.inbox, @response.encode)
    callback.call(@result)
  end

  def option(hash, key)
    if hash.has_key?(key)
      hash[key]
    else
      DEFAULTS[key]
    end
  end

  # Creates a temporary directory with needed layout for staging, along
  # with the correct permissions
  #
  # @param  tmpdir_base  String  If supplied, the temporary directory will be created under this
  #
  # @return Hash                 :base     => Base temporary directory
  #                              :unstaged => Unstaged app dir
  #                              :staged   => Staged app dir
  def create_staging_dirs(tmpdir_base=nil)
    # Created with mode 0700 by default
    ret = {:base => Dir.mktmpdir(nil, tmpdir_base)}

    @vcap_logger.debug("Created base staging dir at #{ret[:base]}")

    for dir_name in ['unstaged', 'staged']
      dir = File.join(ret[:base], dir_name)
      FileUtils.mkdir(dir, :mode => 0700)
      ret[dir_name.to_sym] = dir
      @vcap_logger.debug("Created #{dir_name} dir at #{dir}")
    end

    ret
  end

  # Downloads the zipped application at @download_uri, unzips it, and stores it
  # in dst_dir.
  #
  # NB: We write the url to a file that only we can read in order to avoid
  # exposing auth information. This actually shells out to a helper script in
  # order to avoid putting long running code (the stager) on the data
  # path. We are sacrificing performance for reliability here...
  #
  # @param  dst_dir  String  Where to store the downloaded app
  # @param  tmp_dir  String
  def download_app(dst_dir, tmp_dir)
    uri_path = File.join(tmp_dir, 'stager_dl_uri')
    zipped_app_path = File.join(tmp_dir, 'app.zip')

    File.open(uri_path, 'w+') {|f| f.write(@download_uri) }
    cmd = "#{@download_app_helper_path} #{uri_path} #{zipped_app_path}"
    res = run_logged(cmd)
    unless res[:success]
      @vcap_logger.error("Failed downloading app from '#{@download_uri}'")
      raise VCAP::Stager::AppDownloadError
    end

    res = run_logged("unzip -q #{zipped_app_path} -d #{dst_dir}")
    unless res[:success]
      raise VCAP::Stager::AppUnzipError
    end

  ensure
    FileUtils.rm_f(uri_path)
    FileUtils.rm_f(zipped_app_path)
  end

  # Stages our app into dst_dir, looking for the app source in src_dir
  #
  # @param  src_dir      String  Location of the unstaged app
  # @param  dst_dir      String  Where to place the staged app
  # @param  work_dir     String  Directory to use to place scratch files
  # @param  task_logger  VCAP::Stager::TaskLogger
  def run_staging_plugin(src_dir, dst_dir, work_dir, task_logger)
    plugin_config = {
      'source_dir'    => src_dir,
      'dest_dir'      => dst_dir,
      'environment'   => @app_props,
    }
    plugin_config['secure_user']  = {'uid' => @user[:uid], 'gid' => @user[:gid]}  if @user
    plugin_config['manifest_dir'] = @manifest_dir if @manifest_dir
    plugin_config_path = File.join(work_dir, 'plugin_config.yaml')
    StagingPlugin::Config.to_file(plugin_config, plugin_config_path)
    cmd = "#{@ruby_path} #{@run_plugin_path} #{@app_props['framework']} #{plugin_config_path}"

    @vcap_logger.debug("Running staging command: '#{cmd}'")
    res = run_logged(cmd, 0, @max_staging_duration)

    # Slurp in the plugin log
    plugin_log = File.join(dst_dir, 'logs', 'staging.log')
    if File.exist?(plugin_log)
      File.open(plugin_log, 'r') do |plf|
        begin
          while line = plf.readline
            line.chomp!
            task_logger.info(line)
          end
        rescue EOFError
        end
      end
    end

    if res[:timed_out]
      @vcap_logger.error("Staging timed out")
      raise VCAP::Stager::StagingTimeoutError
    elsif !res[:success]
      @vcap_logger.error("Staging plugin exited with status '#{res[:status]}'")
      raise VCAP::Stager::StagingPluginError, "#{res[:stderr]}"
    end
  ensure
    FileUtils.rm_f(plugin_config_path) if plugin_config_path
  end

  # Stages our app into dst_dir, looking for the app source in src_dir
  #
  # NB: This is the entry point for *new style* staging plugins
  #
  # @param  src_dir      String  Location of the unstaged app
  # @param  dst_dir      String  Where to place the staged app
  # @param  base_dir     String  Directory to use to place scratch files (houses {src,dst} dir)
  def run_plugins(src_dir, dst_dir, base_dir)
    runner_path  = File.join(base_dir, 'plugin_runner')
    gemfile_path = File.join(base_dir, 'Gemfile')
    error_path   = File.join(base_dir, 'plugin_runner_error')

    runner = VCAP::Stager::PluginRunner.new(src_dir, dst_dir, @app_props, @cc_info)
    runner.to_file(runner_path)
    runner_cmd = "#{@ruby_path} %s %s" % [VCAP::Stager::PluginRunner::RUNNER_BIN_PATH, error_path]

    @vcap_logger.debug("Executing plugin runner with command #{runner_cmd}")
    res = run_logged(runner_cmd, 0, @max_staging_duration)

    if res[:timed_out]
      @vcap_logger.error("Plugin runner timed out after #{@max_staging_duration} secs")
      raise VCAP::Stager::StagingTimeoutError

    elsif !res[:success]
      @vcap_logger.error("Failed running staging plugins")

      begin
        err = YAML.load_file(error_path)
      rescue => e
        @vcap_logger.error("Failed reading error file at #{error_path}")
        @vcap_logger.error(e)
        # We can't communicate the specific reason that staging failed (if any),
        # so just raise a generic error.
        raise VCAP::Stager::PluginRunnerError
      end

      @vcap_logger.error(e)
      if err.kind_of?(VCAP::Stager::TaskError)
        raise err
      else
        # Unhandled exception, raise a generic error
        raise VCAP::Stager::PluginRunnerError
      end
    end
  end

  # Packages and uploads the droplet in staged_dir
  #
  # NB: See download_app for an explanation of why we shell out here...
  #
  # @param staged_dir  String
  def upload_droplet(staged_dir, tmp_dir)
    droplet_path = File.join(tmp_dir, 'droplet.tgz')
    cmd = "cd #{staged_dir} && COPYFILE_DISABLE=true tar -czf #{droplet_path} *"
    res = run_logged(cmd)
    unless res[:success]
      raise VCAP::Stager::DropletCreationError
    end

    uri_path = File.join(tmp_dir, 'stager_ul_uri')
    File.open(uri_path, 'w+') {|f| f.write(@upload_uri); f.path }

    cmd = "#{@upload_droplet_helper_path} #{uri_path} #{droplet_path}"
    res = run_logged(cmd)
    unless res[:success]
      @vcap_logger.error("Failed uploading app to '#{@upload_uri}'")
      raise VCAP::Stager::DropletUploadError
    end
  ensure
    FileUtils.rm_f(droplet_path) if droplet_path
    FileUtils.rm_f(uri_path) if uri_path
  end

  # Runs a command, logging the result at the debug level on success, or error level
  # on failure. See VCAP::Stager::Util for a description of the arguments.
  def run_logged(command, expected_exitstatus=0, timeout=nil)
    f = Fiber.current
    VCAP::Stager::Util.run_command(command, expected_exitstatus, timeout) {|res| f.resume(res) }
    ret = Fiber.yield

    level = ret[:success] ? :debug : :error
    @vcap_logger.send(level, "Command '#{command}' exited with status='#{ret[:status]}', timed_out=#{ret[:timed_out]}")
    @vcap_logger.send(level, "stdout: #{ret[:stdout]}") if ret[:stdout] != ''
    @vcap_logger.send(level, "stderr: #{ret[:stderr]}") if ret[:stderr] != ''

    ret
  end

  def get_uid
    ret = run_logged('id')
    if ret[:success]
      ret[:stdout] =~ /uid=(\d+)/ ? $1 : nil
    else
      nil
    end
  end
end
