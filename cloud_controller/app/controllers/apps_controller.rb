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
    @app.purge_all_resources!
    @app.destroy
    render :nothing => true, :status => 200
  end

  # POST /apps/:name/application
  def upload
    begin
      app_bits  = params[:application]
      resources = json_param(:resources)
      package = AppPackage.new(@app, app_bits, resources)
      @app.latest_bits_from(package)
    ensure
      FileUtils.rm_f(app_bits.path)
    end
    render :nothing => true, :status => 200
  end

  def download
    path = @app.package_path
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
      send_file path
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
    raise CloudError.new(CloudError::APP_STOPPED) unless @app.started?
    # Simulate a start call
    error_on_lock_mismatch(@app)
    @app.lock_version += 1
    manager = AppManager.new(@app)
    manager.stage if @app.needs_staging?
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
    # will Fiber.yield
    url, auth = AppManager.new(@app).get_file_url(params[:instance_id], params[:path])
    raise CloudError.new(CloudError::APP_FILE_ERROR, params[:path] || '/') unless url

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

  private

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

    # 'app.save' can actually raise an exception, if whatever is
    # invalid happens all the way down at the DB layer.
    begin
      app.save!
    rescue
      CloudController.logger.debug "Failed to save new app, app invalid"
      raise CloudError.new(CloudError::APP_INVALID)
    end

    # This needs to be called after the app is saved, but before staging.
    update_app_services(app)
    app.save if app.changed?

    # Process any changes that require action on out part here.
    manager = AppManager.new(app)
    manager.stage if app.needs_staging?

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
    app.environment = body_params[:env].uniq
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
      CloudController.logger.debug "No app framework indicated"
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
    CloudController.logger.debug "Adding services: #{added_configs.inspect}"
    CloudController.logger.debug "Removing services: #{removed_configs.inspect}"

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
