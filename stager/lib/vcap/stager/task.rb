require 'fileutils'
require 'redis'
require 'redis-namespace'
require 'tmpdir'
require 'uri'

require 'vcap/logging'
require 'vcap/subprocess'

require 'vcap/stager/plugin'
require 'vcap/stager/task_result'

module VCAP
  module Stager
  end
end

# TODO - Need VCAP::Stager::Task.enqueue(args) w/ validation

# NB: This code is run after the parent worker process forks
class VCAP::Stager::Task
  @queue = :staging

  class << self
    def perform(*args)
      task = self.new(*args)
      task.perform
    end
  end

  attr_reader   :app_id
  attr_reader   :result

  attr_accessor :tmpdir_base
  attr_accessor :max_staging_duration
  attr_accessor :run_plugin_path
  attr_accessor :manifest_dir
  attr_accessor :ruby_path
  attr_accessor :secure_user

  attr_accessor :redis_opts
  attr_accessor :nats_uri

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
  # @param  notify_subj   String  NATS subject that the stager will publish the result to.
  def initialize(app_id, props, download_uri, upload_uri, notify_subj)
    @app_id       = app_id
    @app_props    = props
    @download_uri = download_uri
    @upload_uri   = upload_uri
    @notify_subj  = notify_subj
    @tmpdir_base  = nil              # Temporary directories are created under this path
    @vcap_logger  = VCAP::Logging.logger('vcap.stager.task')

    # XXX - Not super happy about this, but I'm not sure of a better way to do this
    #       given that resque forks after reserving work
    @max_staging_duration = VCAP::Stager.config[:max_staging_duration]
    @run_plugin_path      = VCAP::Stager.config[:run_plugin_path]
    @ruby_path            = VCAP::Stager.config[:ruby_path]
    @redis_opts           = VCAP::Stager.config[:redis]
    @nats_uri             = VCAP::Stager.config[:nats_uri]
    @secure_user          = VCAP::Stager.config[:secure_user]
    @manifest_dir         = VCAP::Stager.config[:dirs][:manifests]
  end

  def perform
    task_logger = VCAP::Stager::TaskLogger.new(@vcap_logger)
    begin
      task_logger.info("Starting staging operation")
      @vcap_logger.debug("App id: #{@app_id}, Properties: #{@app_props}")
      @vcap_logger.debug("download_uri=#{@download_uri} upload_uri=#{@upload_uri} notify_sub=#{@notify_subj}")

      task_logger.info("Setting up temporary directories")
      staging_dirs = create_staging_dirs(@tmpdir_base)

      task_logger.info("Fetching application bits from the Cloud Controller")
      zipped_app_path = File.join(staging_dirs[:base], 'app.zip')
      VCAP::Stager::Util.fetch_zipped_app(@download_uri, zipped_app_path)

      task_logger.info("Unzipping application")
      VCAP::Subprocess.run("unzip -q #{zipped_app_path} -d #{staging_dirs[:unstaged]}")

      task_logger.info("Staging application")
      run_staging_plugin(staging_dirs)

      task_logger.info("Creating droplet")
      zipped_droplet_path = File.join(staging_dirs[:base], 'droplet.tgz')
      VCAP::Subprocess.run("cd #{staging_dirs[:staged]}; COPYFILE_DISABLE=true tar -czf #{zipped_droplet_path} *")

      task_logger.info("Uploading droplet")
      VCAP::Stager::Util.upload_droplet(@upload_uri, zipped_droplet_path)

      @result = VCAP::Stager::TaskResult.new(@app_id,
                                             VCAP::Stager::TaskResult::ST_SUCCESS,
                                             task_logger.public_log)
      task_logger.info("Notifying Cloud Controller")
      save_result
      publish_result
      task_logger.info("Done!")

    rescue VCAP::Stager::ResultPublishingError => e
      # Don't try to publish to nats again if it failed the first time
      task_logger.error("Staging FAILED")
      @result = VCAP::Stager::TaskResult.new(@app_id,
                                             VCAP::Stager::TaskResult::ST_FAILED,
                                             task_logger.public_log)
      save_result
      raise e

    rescue => e
      task_logger.error("Staging FAILED")
      @vcap_logger.error("Caught exception: #{e}")
      @vcap_logger.error(e)
      @result = VCAP::Stager::TaskResult.new(@app_id,
                                             VCAP::Stager::TaskResult::ST_FAILED,
                                             task_logger.public_log)
      save_result
      begin
           publish_result
      rescue => e
        # Let the original exception stay as the cause of failure
        @vcap_logger.error("Failed publishing error to NATS: #{e}")
        @vcap_logger.error(e)
      end
      # Let resque catch and log the exception too
      raise e

    ensure
      FileUtils.rm_rf(staging_dirs[:base]) if staging_dirs
    end


  end

  private

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

  # Stages our app into _staged_dir_ looking for the source in _unstaged_dir_
  def run_staging_plugin(staging_dirs)
    plugin_config = {
      'source_dir'    => staging_dirs[:unstaged],
      'dest_dir'      => staging_dirs[:staged],
      'environment'   => @app_props,
    }
    plugin_config['secure_user'] = @secure_user if @secure_user
    plugin_config['manifest_dir'] = @manifest_dir if @manifest_dir

    plugin_config_path = File.join(staging_dirs[:base], 'plugin_config.yaml')
    StagingPlugin::Config.to_file(plugin_config, plugin_config_path)
    cmd = "#{@ruby_path} #{@run_plugin_path} #{@app_props['framework']} #{plugin_config_path}"
    @vcap_logger.debug("Running staging command: '#{cmd}'")
    res = VCAP::Subprocess.run(cmd, 0, @max_staging_duration)
    @vcap_logger.debug("Staging command exited with status: #{res[0]}")
    @vcap_logger.debug("STDOUT: #{res[1]}")
    @vcap_logger.debug("STDERR: #{res[2]}")
    res
  end

  def publish_result
    begin
      EM.run do
        nats = NATS.connect(:uri => @nats_uri) do
          nats.publish(@notify_subj, @result.encode) { EM.stop }
        end
      end
    rescue => e
      @vcap_logger.error("Failed publishing to NATS (uri=#{@nats_uri}). Error: #{e}")
      @vcap_logger.error(e)
      raise VCAP::Stager::ResultPublishingError, "Error while publishing to #{@nats_uri}"
    end
  end

  # Failure to save our result to redis shouldn't impact whether or not
  # the staging operation succeeds. Consequently, this doesn't throw exceptions.
  def save_result
    begin
      redis = Redis.new(@redis_opts)
      redis = Redis::Namespace.new(@redis_opts[:namespace], :redis => redis)
      @result.save(redis)
    rescue => e
      @vcap_logger.error("Failed saving result to redis: #{e}")
      @vcap_logger.error(e)
    end
  end

end
