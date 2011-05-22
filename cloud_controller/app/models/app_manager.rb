class AppManager
  attr_reader :app

  DEFAULT_MAX_CONCURRENT_STAGERS = 10
  DEFAULT_MAX_STAGING_RUNTIME    = 60

  class << self

    def max_running
      AppConfig[:staging][:max_concurrent_stagers] || DEFAULT_MAX_CONCURRENT_STAGERS
    end

    def max_runtime
      AppConfig[:staging][:max_staging_runtime] || DEFAULT_MAX_STAGING_RUNTIME
    end

    def staging_manifest_directory
      AppConfig[:directories][:staging_manifests]
    end

    def pending
      @pending ||= []
    end

    def running
      @running ||= {}
    end

    def secure_staging_dir(user, dir)
      Rails.logger.debug("SECURE: Securing directory '#{dir}'")
      system("chown -R #{user[:user]} #{dir}")
      system("chgrp -R #{user[:group]} #{dir}")
      system("chmod -R o-rwx #{dir}")
      system("chmod -R g-rwx #{dir}")
    end

    def queue_staging_job(job)
      pending << job
      VCAP::Component.varz[:pending_stage_cmds] = pending.length
      process_queue
    end

    def staging_job_expired(job)
      Rails.logger.warn "STAGING: Killing long running staging process: #{job.inspect}"
      job.delete(:expire_timer)
      # Forcefully take out long running stager
      `kill -9 #{job[:pid]}`
      complete_running(job)
    end

    def mark_running(job, pid)
      job[:pid] = pid
      job[:start] = Time.now
      job[:expire_timer] = EM.add_timer(max_runtime) { AppManager.staging_job_expired(job) }
      running[pid] = job

      VCAP::Component.varz[:running_stage_cmds] = running.length
    end

    def complete_running(job)
      EM.cancel_timer(job[:expire_timer]) if job[:expire_timer]
      if job[:user]
        Rails.logger.debug("SECURE: Checking in user #{job[:user]}")
        `sudo -u '##{job[:user][:uid]}' pkill -9 -U #{job[:user][:uid]} 2>&1`
        SecureUserManager.instance.return_secure_user(job[:user])
        job[:user] = nil
      end
      running.delete job[:pid]
      VCAP::Component.varz[:running_stage_cmds] = running.length
      process_queue
    end

    def process_queue
      return if running.length >= max_running
      return if pending.empty?
      job = pending.shift
      VCAP::Component.varz[:pending_stage_cmds] = pending.length

      Rails.logger.debug "STAGING: starting staging command: #{job[:cmd]}"

      if AppConfig[:staging][:secure]
        job[:user] = user = SecureUserManager.instance.grab_secure_user
        Rails.logger.debug("SECURE: Checked out user #{user.inspect}")

        job[:cmd] = "#{job[:cmd]} #{user[:uid]} #{user[:gid]}"
        Rails.logger.debug("SECURE: Command changed to '#{job[:cmd]}'")

        AppManager.secure_staging_dir(job[:user], job[:staging_dir])
        AppManager.secure_staging_dir(job[:user], job[:exploded_dir])
      end

      Bundler.with_clean_env do

        pid = EM.system(job[:cmd]) do |output, status|

          if status.exitstatus != 0
            Rails.logger.debug "STAGING: staging command FAILED with #{status.exitstatus}: #{output}"
          else
            Rails.logger.debug 'STAGING: staging command SUCCEEDED'
          end

          Fiber.new do
            # Finalize staging here if all is well.
            manager = AppManager.new(job[:app])
            begin
              if manager.app_still_exists? # Will reload app
                # Save the app even if staging failed to display the log to the user
                manager.package_staged_app(job[:staging_dir])
                job[:app].package_state = 'FAILED' if status.exitstatus != 0
                manager.save_staged_app_state
              end
            rescue => e
              Rails.logger.warn "STAGING: Exception after return from staging: #{e}"
            ensure
              FileUtils.rm_rf(job[:staging_dir])
              FileUtils.rm_rf(job[:exploded_dir])
            end
          end.resume

          # Clean up running reference
          complete_running(job)

        end
        mark_running(job, pid)

      end
    end

  end

  def initialize(app)
    @app = app
  end

  def run_staging_command(script, exploded_dir, staging_dir, env_json)
    job = {
      :app => @app,
      :cmd => "#{script} #{exploded_dir} #{staging_dir} #{env_json} #{AppManager.staging_manifest_directory}",
      :staging_dir => staging_dir,
      :exploded_dir => exploded_dir
    }

    Rails.logger.info("STAGING: queueing staging command #{job[:cmd]}")

    AppManager.queue_staging_job(job)
  end

  def health_manager_message_received(payload)
    Rails.logger.debug("[HealthManager] Received #{payload[:op]} request for app #{app.id} - #{app.name}")

    indices = payload[:indices]
    message = new_message

    case payload[:op]
    when /START/i
      # Check if App is started.
      unless app.started?
        Rails.logger.debug("[HealthManager] App no longer running, ignoring")
        return
      end
      # Only process start requests for current version.
      unless app.generate_version == payload[:version]
        Rails.logger.debug("[HealthManager] Request for older version of app, ignoring")
        return
      end
      Rails.logger.debug("[HealthManager] Starting #{indices.length} missing instances for app: #{app.id}")
      # FIXME - Check capacity
      indices.each { |i| start_instance(message, i) }
    when /STOP/i
      # If HM detects older versions, let's clean up here versus suppressing
      # and leaving old versions in the system. HM will start new ones if needed.
      if payload[:last_updated] == app.last_updated
        stop_msg = { :droplet => app.id, :instances => payload[:instances] }
        NATS.publish('dea.stop', Yajl::Encoder.encode(stop_msg))
      end
    end
  end

  def once_app_is_staged
    elapsed = perform_deferred_app_operation(360.0) do |app|
      if app.staged? || app.staging_failed?
        yield
        true
      end
    end
  end

  def start_instances(start_message, index, max_to_start)
    EM.next_tick do
      f = Fiber.new do
        message = start_message.dup
        message[:executableUri] = download_app_uri(message[:executableUri])
        (index...max_to_start).each do |i|
          message[:index] = i
          dea_id = find_dea_for(message)
          if dea_id
            json = Yajl::Encoder.encode(message)
            Rails.logger.debug("Sending start message #{json} to DEA #{dea_id}")
            NATS.publish("dea.#{dea_id}.start", json)
          else
            Rails.logger.warn("No resources available to start instance #{json}")
          end
        end
      end
      f.resume
    end
  end

  def started
    once_app_is_staged do
      save_staged_app_state # Bumps runcount
      message = new_message
      # Start a single instance on staging failure to display staging errors to user
      num_to_start = app.staging_failed? ? 1 : app.instances
      start_instances(message, 0, num_to_start)
    end
  end

  def stopped
    stop_all
  end

  def change_running_instances(delta)
    return unless app.started?
    message = new_message
    if (delta > 0)
      start_instances(message, app.instances - delta, app.instances)
    else
      indices = (app.instances...(app.instances - delta)).collect { |i| i }
      stop_instances(indices)
    end
  end

  def update_uris
    return unless app.staged?
    message = new_message
    json = Yajl::Encoder.encode(message)
    NATS.publish('dea.update', json)
  end

  def updated
    once_app_is_staged do
      unless app.staging_failed?
        NATS.publish('droplet.updated', Yajl::Encoder.encode(:droplet => app.id))
      end
    end
  end

  def update_run_count
    if app.staged_package_hash_changed?
      app.run_count = 0 # reset
    else
      app.run_count += 1
    end
  end

  def save_staged_app_state
    update_run_count
    if !app.save
      errors = app.errors.full_messages
      Rails.logger.warn "STAGING: App #{app.id} was not valid after attempted staging: #{errors.join(',')}"
    end
  end

  def manifest_for_framework(framework)
    candidate_paths = [
      File.join(AppManager.staging_manifest_directory, "#{framework}.yml"),
      Rails.root.join('staging', 'manifests', "#{framework}.yml").to_s
    ]

    candidate_paths.each do |path|
      return StagingPlugin.load_manifest(path) if File.exists?(path)
    end
    nil
  end

  def stage
    return if app.package_hash.blank? || app.staged?

    manifest = manifest_for_framework(app.framework)

    unless manifest && manifest['runtimes']
      raise CloudError.new(CloudError::APP_INVALID_FRAMEWORK, app.framework)
    end

    runtime = nil
    manifest['runtimes'].each do |hash|
      runtime ||= hash[app.runtime]
    end

    unless runtime
      raise CloudError.new(CloudError::APP_INVALID_RUNTIME, app.runtime, app.framework)
    end

    env_json = Yajl::Encoder.encode(app.staging_environment)

    staging_plugin_dir = Rails.root.join('staging', app.framework.to_s)

    unless File.exists?(staging_plugin_dir)
      raise CloudError.new(CloudError::APP_INVALID_FRAMEWORK, app.framework)
    end

    app_source_dir = Dir.mktmpdir
    app.explode_into(app_source_dir)
    output_dir = Dir.mktmpdir
    # Call the selected staging script without changing directories.
    staging_script = "#{CloudController.current_ruby} #{File.join(staging_plugin_dir, 'stage')}"
    # Perform staging command
    run_staging_command(staging_script, app_source_dir, output_dir, env_json)

  rescue => e
    Rails.logger.warn "STAGING: Failed on exception! #{e}"
    app.package_state = 'FAILED'
    save_staged_app_state
    raise e # re-raise here to propogate to the API call.
  end

  # Returns an array of hashes containing 'index', 'state', and 'since'(timestamp)
  # for all instances running, or trying to run, the app.
  def find_instances
    return [] unless app.started?
    instances = app.instances
    indices = []

    message = {
      :droplet => app.id,
      :version => app.generate_version,
      :state => :FLAPPING
    }

    flapping_indices_json = NATS.timed_request('healthmanager.status', message.to_json, :timeout => 2).first
    flapping_indices = Yajl::Parser.parse(flapping_indices_json, :symbolize_keys => true) rescue nil
    if flapping_indices && flapping_indices[:indices]
      flapping_indices[:indices].each do |entry|
        index = entry[:index]
        if index >= 0 && index < instances
          indices[index] = {
            :index => index,
            :state => :FLAPPING,
            :since => entry[:since]
          }
        end
      end
    end

    message = {
      :droplet => app.id,
      :version => app.generate_version,
      :states => ['STARTING', 'RUNNING']
    }

    expected_running_instances = instances - indices.length

    if expected_running_instances > 0
      opts = { :timeout => 2, :expected => expected_running_instances }
      running_instances = NATS.timed_request('dea.find.droplet', message.to_json, opts)
      running_instances.each do |instance|
        instance_json = Yajl::Parser.parse(instance, :symbolize_keys => true) rescue nil
        next unless instance_json
        index = instance_json[:index] || instances
        if index >= 0 && index < instances
          indices[index] = {
            :index => index,
            :state => instance_json[:state],
            :since => instance_json[:state_timestamp]
          }
        end
      end
    end

    instances.times do |index|
      index_entry = indices[index]
      unless index_entry
        indices[index] = { :index => index, :state => :DOWN, :since => Time.now.to_i }
      end
    end
    indices
  end

  def find_crashes
    crashes = []
    message = {:droplet => app.id, :state => :CRASHED}
    crashed_indices_json = NATS.timed_request('healthmanager.status', message.to_json, :timeout => 2).first
    crashed_indices = Yajl::Parser.parse(crashed_indices_json, :symbolize_keys => true) rescue nil
    crashes = crashed_indices[:instances] if crashed_indices
    crashes
  end

  # TODO, this should be calling one generic find_instances
  def find_specific_instance(options)
    message = { :droplet => app.id }
    message.merge!(options)
    instance_json = NATS.timed_request('dea.find.droplet', message.to_json, :timeout => 2).first
    instance = Yajl::Parser.parse(instance_json, :symbolize_keys => true) rescue nil
  end

  # TODO - This has a lot in common with 'find_instances'; at the very
  # least, the 'fill remaining slots with 'DOWN' instances' code should
  # be refactored out.
  def find_stats
    indices = {}
    return indices if (app.nil? || !app.started?)

    message = { :droplet => app.id, :version => app.generate_version,
                :states => ['RUNNING'], :include_stats => true }
    opt = { :timeout => 2, :expected => app.instances }
    running_instances = NATS.timed_request('dea.find.droplet', message.to_json, opt)

    running_instances.each do |instance|
      instance_json = Yajl::Parser.parse(instance, :symbolize_keys => true)
      index = instance_json[:index]
      if index >= 0 && index < app.instances
        indices[index] = {
          :state => instance_json[:state],
          :stats => instance_json[:stats]
        }
      end
    end

    app.instances.times do |index|
      index_entry = indices[index]
      unless index_entry
        indices[index] = {
          :state => :DOWN,
          :since => Time.now.to_i
        }
      end
    end

    indices
  end

  def download_app_uri(path)
    ['http://', "#{CloudController.bind_address}:#{CloudController.instance_port}", path].join
  end

  # start_instance involves several moving pieces, from sending requests for help to the
  # dea_pool, to sending the actual start messages. In addition, many of these can be
  # triggered by one update call, so we simply queue them for the next go around through
  # the event loop with their own fiber context
  def start_instance(message, index)
    # Release any pending api call.
    EM.next_tick do
      wf = Fiber.new do
        message = message.dup
        message[:executableUri] = download_app_uri(message[:executableUri])
        message[:index] = index
        dea_id = find_dea_for(message)
        if dea_id
          json = Yajl::Encoder.encode(message)
          Rails.logger.debug("Sending start message #{json} to DEA #{dea_id}")
          NATS.publish("dea.#{dea_id}.start", json)
        else
          Rails.logger.warn("No resources available to start instance #{json}")
        end
      end
      wf.resume
    end
  end

  def find_dea_for(message)
    find_dea_message = {
      :droplet => message[:droplet],
      :limits => message[:limits],
      :name => message[:name],
      :runtime => message[:runtime],
      :sha => message[:sha1]
    }
    json_msg = Yajl::Encoder.encode(find_dea_message)
    result = NATS.timed_request('dea.discover', json_msg, :timeout => 2).first
    return nil if result.nil?
    Rails.logger.debug "Received #{result.inspect} in response to dea.discover request"
    Yajl::Parser.parse(result, :symbolize_keys => true)[:id]
  end

  def stop_instances(indices)
    stop_msg = { :droplet => app.id, :version => app.generate_version, :indices => indices }
    NATS.publish('dea.stop', Yajl::Encoder.encode(stop_msg))
  end

  def stop_all
    NATS.publish('dea.stop', Yajl::Encoder.encode(:droplet => app.id))
  end

  def get_file_url(instance, path=nil)
    raise CloudError.new(CloudError::APP_STOPPED) if app.stopped?

    search_options = {}

    if instance =~ /^\d{1,10}$/
      instance = instance.to_i
      if instance < 0 || instance >= app.instances
        raise CloudError.new(CloudError::APP_INSTANCE_NOT_FOUND, instance)
      end
      search_options[:indices] = [instance]
      search_options[:states] = [:STARTING, :RUNNING, :CRASHED]
      search_options[:version] = app.generate_version
    else
      search_options[:instance_ids] = [instance]
    end
    if instance = find_specific_instance(search_options)
      ["#{instance[:file_uri]}#{instance[:staged]}/#{path}", instance[:credentials]]
    end
  end

  def perform_deferred_app_operation(time_limit = 30.0)
    raise ArgumentError, "method requires a block" unless block_given?
    start_time = Time.now
    elapsed = 0.0
    should_exit = false
    until should_exit || elapsed > time_limit
      break unless app_still_exists?
      should_exit = yield(app)
      elapsed = (Time.now - start_time)
      fiber_sleep(0.5) unless should_exit
    end
    elapsed
  end

  def new_message
    data = {:droplet => app.id, :name => app.name, :uris => app.mapped_urls}
    data[:runtime] = app.runtime
    data[:framework] = app.framework
    data[:sha1] = app.staged_package_hash
    data[:executableFile] = app.staged_package_path
    data[:executableUri] = "/staged_droplets/#{app.id}/#{app.staged_package_hash}"
    data[:version] = app.generate_version
    data[:services] = app.service_bindings.map do |sb|
      cfg = sb.service_config
      svc = cfg.service
      { :name    => cfg.alias,
        :type    => svc.synthesize_service_type,
        :label   => svc.label,
        :vendor  => svc.name,
        :version => svc.version,
        :tags    => svc.tags,
        :plan    => cfg.plan,
        :plan_option => cfg.plan_option,
        :credentials => sb.credentials,
      }
    end
    data[:limits] = app.limits
    data[:env] = app.environment_variables
    data[:users] = [app.owner.email]  # XXX - should we collect all collabs here?
    data
  end

  def app_still_exists?
    @app && @app = App.uncached { App.find_by_id(@app.id) }
  end

  def fiber_sleep(secs)
    f = Fiber.current
    EM.add_timer(secs) { f.resume }
    Fiber.yield
  end

  # Update the SHA1 stored for the app, repack the new bits, and mark the app as staged.
  # repack does the right thing but needs a Fiber context, which will not be present here
  def package_staged_app(staging_dir)
    tmpdir = Dir.mktmpdir # we create the working directory ourselves so we can clean it up.
    staged_file = AppPackage.repack_app_in(staging_dir, tmpdir, :tgz)

    # Remove old one if needed
    unless app.staged_package_hash.nil?
      staged_package = File.join(AppPackage.package_dir, app.staged_package_hash)
      FileUtils.rm_f(staged_package)
    end

    app.staged_package_hash = Digest::SHA1.file(staged_file).hexdigest

    FileUtils.mv(staged_file, app.staged_package_path) unless File.exists?(app.staged_package_path)
    app.package_state = 'STAGED'
  rescue
    app.package_state = 'FAILED'
  ensure
    FileUtils.rm_rf(tmpdir)
    FileUtils.rm_rf(File.dirname(staged_file)) if staged_file
  end
end
