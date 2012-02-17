require 'staging_task_manager'

class AppsController < ApplicationController
  before_filter :require_user, :except => [:download_staged]
  before_filter :find_app_by_name, :except => [:create, :list, :download_staged]

  def process_action(method_name, *args)
    app = @app ? @app.name : (params[:name] || (body_params && body_params[:name]))
    @event_args = [app]
    super(method_name, *args)
  end

  # POST /apps
  def create
    name = body_params[:name]
    app = ::App.new(:owner => user, :name => name)
    begin
      update_app_from_params(app)
    rescue => e
      app.destroy
      raise e
    end
    app_url = app_get_url(name)
    render :json => {:result => 'success',  :redirect => app_url }, :location => app_url, :status => 302
  end

  # PUT /apps/:name
  def update
    update_app_from_params(@app)
    render :nothing => true
  end

  def get
    render :json => @app.as_json
  end

  def stats
    render :json => AppManager.new(@app).find_stats
  end

  def list
    render :json => user.get_apps.to_a
  end

  def delete
    CloudController.logger.info("Deleting app, name=#{@app.name} id=#{@app.id}")
    @app.purge_all_resources!
    @app.destroy
    render :nothing => true, :status => 200
  end

  def valid_upload_path?(path)
    path.starts_with?(CloudController.uploads_dir)
  end

  def get_uploaded_file
    file = nil
    if CloudController.use_nginx
      path = params[:application_path]
      if path != nil
        if not valid_upload_path?(path)
          CloudController.logger.warn "Illegal path: #{path}, passed to cloud_controller
                                       something is badly misconfigured or insecure!!!"
          raise CloudError.new(CloudError::FORBIDDEN)
        end
        wrapper_class = Class.new do
          attr_accessor :path
        end
        file = wrapper_class.new
        file.path = path
      end
    else
      file = params[:application]
    end
    file
  end

  # POST /apps/:name/application
  def upload
    begin
      file = get_uploaded_file
      resources = json_param(:resources)
      package = AppPackage.new(@app, file, resources)
      @app.latest_bits_from(package)
    rescue AppPackageError => e
      CloudController.logger.error(e)
      raise CloudError.new(CloudError::RESOURCES_PACKAGING_FAILED, e.to_s)
    ensure
      FileUtils.rm_f(file.path) if file
    end
    render :nothing => true, :status => 200
  end

  def download
    path = @app.unstaged_package_path
    if path && File.exists?(path)
      send_file path
    else
      raise CloudError.new(CloudError::APP_NOT_FOUND)
    end
  end

  def download_staged
    app = App.find_by_id(params[:id])
    raise CloudError.new(CloudError::APP_NOT_FOUND) unless app && (app.staged_package_hash == params[:hash])

    path = app.staged_package_path
    if path && File.exists?(path)
      if CloudController.use_nginx
        response.headers['X-Accel-Redirect'] = '/droplets/' + File.basename(path)
        render :nothing => true, :status => 200
      else
        send_file path
      end
    else
      raise CloudError.new(CloudError::APP_NOT_FOUND)
    end
  end

  def crashes
    render :json => {:crashes => @app.find_recent_crashes}
  end

  def instances
    render :json => {:instances =>  @app.find_instances}
  end

  # PUT /apps/:name/update
  def start_update
    CloudController.logger.debug "app: #{@app.id} start_update"
    raise CloudError.new(CloudError::APP_STOPPED) unless @app.started?
    # Simulate a start call
    error_on_lock_mismatch(@app)
    @app.lock_version += 1
    manager = AppManager.new(@app)
    if @app.needs_staging?
      if user.uses_new_stager?
        stage_app(@app)
      else
        manager.stage
      end
    end
    manager.stop_all
    manager.started
    render :nothing => true, :status => 204
  end

  # GET /apps/:name/update
  # This is simple now versus older version, but need to hack old behavior
  def check_update
    data = { :state => :NONE, :since => @app.last_updated }

    if @app.state =~ /STARTED/i
      case @app.package_state
      when /PENDING/i
        data[:state] = :UPDATING
      when /FAILED/i
        data[:state] = :CANARY_FAILED
      when /STAGED/i
        running = @app.running_instances
        if (running == @app.instances)
          data[:state] = :SUCCEEDED
        else
          # Check for crashes, or leave as updating
          crashes = @app.find_recent_crashes
          if crashes.empty?
            data[:state] = :UPDATING
          else
            data[:state] = :CANARY_FAILED
          end
        end
      end
    else
      data[:state] = :CANARY_FAILED
    end

    render :json => data
  end

  # GET /apps/:name/instances/:instance_id/files/:path'
  def files
    # XXX - Yuck. This will have to do until we update VMC with a real
    #       way to fetch staging logs.
    if user.uses_new_stager? && (params[:path] == 'logs/staging.log')
      log = StagingTaskLog.fetch_fibered(@app.id)
      if log
        render :text => log.task_log
      else
        render :nothing => true, :status => 404
      end
      return
    end

    # will Fiber.yield
    url, auth = AppManager.new(@app).get_file_url(params[:instance_id], params[:path])
    raise CloudError.new(CloudError::APP_FILE_ERROR, params[:path] || '/') unless url

    if CloudController.use_nginx
      CloudController.logger.debug "X-Accel-Redirect for #{url}"
      auth_info = Base64.strict_encode64("#{auth[0]}:#{auth[1]}")
      auth_str = "Basic #{auth_info}"
      response.headers['X-Auth'] = auth_str
      response.headers['X-Accel-Redirect'] = '/internal_redirect/'+ url
      render :nothing => true, :status => 200
    else
      # FIXME, need to stream responses. Seems broken with Fibers, EM,
      # and response_body=proc
      # will Fiber.yield
      http = http_aget(url, auth)
      if http.response_header.status != 200
        raise CloudError.new(CloudError::APP_FILE_ERROR, params[:path] || '/')
      end
      # We ignore headers here since upstream will redo as they see fit
      #render :text => http.response, :status => 200
      self.response_body = http.response
    end
  end

  private

  def stage_app(app)
    task_mgr = StagingTaskManager.new(:logger  => CloudController.logger,
                                      :timeout => AppConfig[:staging][:max_staging_runtime])
    dl_uri = StagingController.download_app_uri(app)
    ul_hdl = StagingController.create_upload(app)

    result = task_mgr.run_staging_task(app, dl_uri, ul_hdl.upload_uri)

    # Update run count to be consistent with previous staging code
    if result.was_success?
      CloudController.logger.debug("Staging task for app_id=#{app.id} succeded.", :tags => [:staging])
      CloudController.logger.debug1("Details: #{result.task_log}", :tags => [:staging])
      app.update_staged_package(ul_hdl.upload_path)
      app.package_state = 'STAGED'
      app.update_run_count()
    else
      CloudController.logger.warn("Staging task for app_id=#{app.id} failed: #{result.error}",
                                  :tags => [:staging])
      CloudController.logger.debug1("Details: #{result.task_log}", :tags => [:staging])
      raise CloudError.new(CloudError::APP_STAGING_ERROR, result.error.to_s)
    end

  rescue => e
    # It may be the case that upload from the stager will happen sometime in the future.
    # Mark the upload as completed so that any upload that occurs in the future will fail.
    if ul_hdl
      StagingController.complete_upload(ul_hdl)
      FileUtils.rm_f(ul_hdl.upload_path)
    end
    # This is in keeping with the old CC behavior. Instead of starting a single
    # instance of a broken app (which is effectively stopped after HM flapping logic
    # is triggered) we stop it explicitly.
    app.state = 'STOPPED'
    AppManager.new(app).stopped
    app.package_state = 'FAILED'
    app.update_run_count()
    raise e

  ensure
    app.save!
  end

  def find_app_by_name
    # XXX - What do we want semantics to be like for multiple apps w/ same name (possible w/ contribs)
    @app = user.apps_owned.find_by_name(params[:name])
    raise CloudError.new(CloudError::APP_NOT_FOUND) unless @app

    # TODO - Deliberately leaving off 'user.admin? ||' here.
    # This logic requires admins to proxy as the user that owns the app.
    # Is it OK to be this draconian?

    #raise CloudError.new(CloudError::APP_NOT_FOUND) unless @app.user == user
    raise CloudError.new(CloudError::APP_NOT_FOUND) unless @app.collaborator?(user)
  end

  # Checks to make sure the update can proceed, then updates the given
  # App from the request params and makes the necessary AppManager calls.
  def update_app_from_params(app)
    CloudController.logger.debug "app: #{app.id || "nil"} update_from_parms"
    error_on_lock_mismatch(app)
    app.lock_version += 1

    previous_state = app.state
    update_app_state(app)
    # State needs to be changed from above before capacity check.
    check_has_capacity_for?(app, previous_state)
    check_app_uris(app)
    update_app_mem(app)
    update_app_env(app)
    update_app_staging(app)
    delta_instances = update_app_instances(app)

    changed = app.changed
    CloudController.logger.debug "app: #{app.id} Updating #{changed.inspect}"

    # reject attempts to start in debug mode if debugging is disabled
    if body_params[:debug] and app.state == 'STARTED' and !AppConfig[:allow_debug]
      raise CloudError.new(CloudError::APP_DEBUG_DISALLOWED)
    end

    app.metadata[:debug] = body_params[:debug] if body_params
    app.metadata[:console] = body_params[:console] if body_params

    # 'app.save' can actually raise an exception, if whatever is
    # invalid happens all the way down at the DB layer.
    begin
      app.save!
    rescue
      CloudController.logger.error "app: #{app.id} Failed to save new app errors: #{app.errors}"
      raise CloudError.new(CloudError::APP_INVALID)
    end

    # This needs to be called after the app is saved, but before staging.
    update_app_services(app)
    app.save if app.changed?

    # Process any changes that require action on out part here.
    manager = AppManager.new(app)

    if app.needs_staging?
      if user.uses_new_stager?
        stage_app(app)
      else
        manager.stage
      end
    end

    if changed.include?('state')
      if app.stopped?
        manager.stopped
      elsif app.started?
        manager.started
      end
      manager.updated
    elsif app.started?
      # Instances (up or down) and uris we will handle in place, since it does not
      # involve staging changes.
      if changed.include?('instances')
        manager.change_running_instances(delta_instances)
        manager.updated

        user_email = user ? user.email : 'N/A'
        CloudController.events.user_event(user_email, app.name, "Changing instances to #{app.instances}", :SUCCEEDED)

      end
    end

    # Now add in URLs
    manager.update_uris if update_app_uris(app)

    yield(app) if block_given?
  end

  def update_app_mem(app)
    return unless body_params && body_params[:resources] && body_params[:resources][:memory]
    app.memory = body_params[:resources][:memory].to_i
  end

  def update_app_env(app)
    return unless body_params && body_params[:env]
    env = body_params[:env].uniq
    env_new = env.delete_if {|e| e =~ /^(vcap|vmc)_/i }
    raise CloudError.new(CloudError::FORBIDDEN) if env != env_new
    app.environment = env
  end

  def update_app_instances(app)
    return 0 unless body_params && body_params[:instances]
    updated_instances = body_params[:instances].to_i
    current_instances = app.instances
    app.instances = updated_instances
    updated_instances - current_instances
  end

  def error_on_lock_mismatch(app)
    if body_params && body_params[:meta] && body_params[:meta][:version]
      if body_params[:meta][:version].to_i != app.lock_version
        raise CloudError.new(CloudError::LOCKING_ERROR)
      end
    end
  end

  def check_app_uris(app)
    return unless body_params && body_params[:uris]
    uris = body_params[:uris]
    # Normalize URLs
    uris.each { |u| u.gsub!(/^http(s*):\/\//i, '') }
    limit = app.owner.account_capacity[:app_uris]
    if uris.length > limit
      raise CloudError.new(CloudError::ACCOUNT_APP_TOO_MANY_URIS, uris.length, limit)
    end
  end

  # Only call this after an app has been saved.
  def update_app_uris(app)
    return false unless body_params && body_params[:uris]
    app.set_urls(body_params[:uris])
  end

  def update_app_staging(app)
    if body_params && body_params[:staging]
      # This is the legacy model, we will continue to support that for now.
      if body_params[:staging][:model]
        app.framework = body_params[:staging][:model]
        app.runtime = body_params[:staging][:stack]
      else
        app.framework = body_params[:staging][:framework]
        app.runtime = body_params[:staging][:runtime]
      end
    end
    unless app.framework
      CloudController.logger.error "app: #{app.id} No app framework indicated"
      raise CloudError.new(CloudError::APP_INVALID_FRAMEWORK, 'NONE')
    end
  end

  def update_app_state(app)
    return if body_params.nil?
    state = body_params[:state]
    return if state.nil? || app.state.to_s =~ /#{state}/i
    case state
    when /STARTED/i
      app.state = 'STARTED'
    when /STOPPED/i
      app.state = 'STOPPED'
    end
  end

  # This is needed to support the legacy VMC client
  # only call this after an app has been saved
  def update_app_services(app)
    return if body_params.nil?
    added_configs, removed_configs = app.diff_configs(body_params[:services])
    return if added_configs.empty? && removed_configs.empty?
    CloudController.logger.debug "app: #{app.id} Adding services: #{added_configs.inspect}"
    CloudController.logger.debug "app: #{app.id} Removing services: #{removed_configs.inspect}"

    # Bind services
    added_configs.each do |cfg_alias|
      cfg = ServiceConfig.find_by_alias_and_user_id(cfg_alias, user.id)
      raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
      raise CloudError.new(CloudError::FORBIDDEN) unless app.collaborator?(user)
      app.bind_to_config(cfg)
    end

    # Unbind services
    removed_configs.each do |cfg_alias|
      cfg = ServiceConfig.find_by_alias_and_user_id(cfg_alias, user.id)
      raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
      raise CloudError.new(CloudError::FORBIDDEN) unless app.collaborator?(user)
      app.unbind_from_config(cfg)
    end
    # Since we made binding changes, we expect to be restaged.
    app.package_state = 'PENDING'
  end

  # Note that the state needs to be updated prior to calling this check.
  def check_has_capacity_for?(app, previous_state)
    return unless body_params
    owner = app.owner
    # If we are creating this app, check to make sure the user
    # has not allocated too many apps, regardless of state.
    if app.new_record?
      if current_apps = owner.no_more_apps?
        app_quota = owner.account_capacity[:apps]
        raise CloudError.new(CloudError::ACCOUNT_APPS_TOO_MANY, current_apps, app_quota)
      end
    end

    # Only worry about apps that are running or they want to run.
    return true unless app.state =~ /STARTED/i

    # Whether it is a creation or an update, check memory capacity.
    memory    = body_params[:resources] && body_params[:resources][:memory]
    instances = body_params[:instances] || app.instances
    per_instance = memory || app.memory
    existing = (previous_state =~ /STARTED/i) ? app.total_memory : 0

    unless owner.has_memory_for?(instances, per_instance, existing, previous_state)
      mem_quota = owner.account_capacity[:memory]
      raise CloudError.new(CloudError::ACCOUNT_NOT_ENOUGH_MEMORY, "#{mem_quota}M")
    end
  end


end
