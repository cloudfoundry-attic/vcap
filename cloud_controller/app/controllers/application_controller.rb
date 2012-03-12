class ApplicationController < ActionController::Base
  # use before_filter :require_user or :require_admin in subclasses to enforce logged-in status.
  before_filter :fetch_user_from_token
  rescue_from Exception, :with => :handle_general_exception
  rescue_from CloudError, :with => :render_cloud_error
  rescue_from ActiveRecord::StaleObjectError, :with => :handle_locking_error

  def process_action(method_name, *args)

    unless VCAP::Component.varz.nil?
      VCAP::Component.varz[:requests] += 1
      VCAP::Component.varz[:pending_requests] += 1
    end

    @error = nil
    ret = super

    if CloudController.events # Not set in test environment.
      user_email = user ? user.email : 'N/A'
      method = "#{request.method}:#{request.path}"
      status = @error ? [:FAILED, @error.to_s] : [:SUCCEEDED]
      ev_args = @event_args || []
      ev_args.compact!
      CloudController.events.user_event(user_email, method, *@event_args, *status)
    end

    ret

  ensure
    VCAP::Component.varz[:pending_requests] -= 1 unless VCAP::Component.varz.nil?
  end

  protected
  def http_aget(url, auth)
    f = Fiber.current
    http = EM::HttpRequest.new(url).get :head => { "authorization" => auth }
    http.errback  { f.resume(http) }
    http.callback { f.resume(http) }
    return Fiber.yield
  end

  def user
    @proxy_user || @current_user
  end

  def body_params
    if request.body.blank?
      {}
    else
      @body_params ||= Yajl::Parser.parse(request.body.read, :symbolize_keys => true)
    end
  rescue Yajl::ParseError
    raise CloudError.new(CloudError::BAD_REQUEST)
  end

  def request_body
    request.body.rewind
    request.body.read
  end

  def json_param(name)
    raw = params[name]
    Yajl::Parser.parse(raw, :symbolize_keys => true)
  rescue Yajl::ParseError => e
    CloudController.logger.error("json_param yajl error: #{e.message}")
    raise CloudError.new(CloudError::BAD_REQUEST)
  end

  def fetch_user_from_token
    reset_user!
    unless auth_token_header.blank?
      user_email = nil
      if uaa_enabled? && UaaToken.is_uaa_token?(auth_token_header)
        user_email = UaaToken.decode_token(auth_token_header)
      else
        token = UserToken.decode(auth_token_header)
        if token.valid?
          user_email = token.user_name
        end
      end

      if (!user_email.nil?)
        CloudController.logger.debug("user_email decoded from token is #{user_email.inspect}")
        @current_user = ::User.find_by_email(user_email)
      end

      unless @current_user.nil?
        if AppConfig[:https_required] or (@current_user.admin? and AppConfig[:https_required_for_admins])
          raise CloudError.new(CloudError::HTTPS_REQUIRED) unless request_https?
        end
      end
    end
    fetch_proxy_user
  rescue UserToken::DecodeError
    CloudController.logger.warn "Invalid user token in request: #{auth_token_header.inspect}"
  end

  def reset_user!
    @current_user, @proxy_user = nil, nil
  end

  def fetch_proxy_user
    return if proxy_user_header.blank?
    evs = [(@current_user ? @current_user.email : 'UNKNOWN_USER'),'PROXY ATTEMPT', proxy_user_header]
    if @current_user && @current_user.admin?
      @proxy_user = ::User.find_by_email(proxy_user_header)
      if @proxy_user.nil?
        CloudController.events.sys_event(*evs, :FAILED, CloudError::USER_NOT_FOUND[2])
        raise CloudError.new(CloudError::USER_NOT_FOUND)
      end
    else
      CloudController.events.sys_event(*evs, :FAILED, CloudError::FORBIDDEN[2])
      raise CloudError.new(CloudError::FORBIDDEN)
    end
    CloudController.events.sys_event(*evs, :SUCCEEDED)
  end

  def require_user
    unless user
      CloudController.logger.error("Authentication failure: #{auth_token_header.inspect}", :tags => [:auth_failure])
      raise CloudError.new(CloudError::FORBIDDEN)
    end
  end

  def require_admin
    unless user && user.admin?
      CloudController.logger.warn("Authentication failure: #{auth_token_header.inspect}", :tags => [:auth_failure])
      raise CloudError.new(CloudError::FORBIDDEN)
    end
  end

  def auth_token_header
    request.headers['HTTP_AUTHORIZATION']
  end

  def proxy_user_header
    request.headers['HTTP_PROXY_USER']
  end

  def remote_request?
    request.remote_ip != '127.0.0.1'
  end

  def request_https?
    (!request.headers["X-Forwarded_Proto"].nil? and request.headers["X-Forwarded_Proto"] =~ /^https/i) ? true : false
  end


  def log_exception(e)
    begin
      CloudController.logger.error "Exception Caught (#{e.class.name}): #{e.to_s}"
      CloudController.logger.error e
    rescue
      # Do nothing
    end
  end

  def render_cloud_error(e)
    @error = e
    render :status => e.status, :json => e.to_json
  end

  def handle_locking_error(e)
    log_exception(e)
    render_cloud_error CloudError.new(CloudError::LOCKING_ERROR)
  end

  def handle_general_exception(e)
    log_exception(e)
    render_cloud_error CloudError.new(CloudError::SYSTEM_ERROR)
  end

  def uaa_enabled?
    AppConfig[:uaa][:enabled] && !AppConfig[:uaa][:url].nil?
  end

end
