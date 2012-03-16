require 'uaa/user_account'

class UsersController < ApplicationController
  before_filter :enforce_registration_policy, :only => :create
  before_filter :grab_event_user
  before_filter :require_user, :except => :create
  before_filter :require_admin, :only => [:delete, :list]

  def create
    if uaa_enabled?
      begin
        user_account = Cloudfoundry::Uaa::UserAccount.new(AppConfig[:uaa][:url], UaaToken.access_token)
        user_account.async = true
        user_account.trace = true
        user_account.logger = CloudController.logger
        user = user_account.create(body_params[:email], body_params[:password], body_params[:email])

        CloudController.logger.info("User with email #{body_params[:email]} and id #{user[:id]} created in the UAA") unless user == nil
      rescue => e
        CloudController.logger.error("Error trying to create a UAA user - message #{e.message} trace #{e.backtrace[0..10]}")
      end
    end

    user = ::User.new :email => body_params[:email]
    user.set_and_encrypt_password(body_params[:password])

    if user.save
      render :status => 204, :nothing => true
    else
      raise CloudError.new(CloudError::BAD_REQUEST)
    end
  end

  def delete
    if uaa_enabled?
      begin
        user_account = Cloudfoundry::Uaa::UserAccount.new(AppConfig[:uaa][:url], UaaToken.access_token)
        user_account.async = true
        user_account.trace = true
        user_account.logger = CloudController.logger
        user_account.delete_by_name(params['email'])
      rescue => e
        CloudController.logger.error("Error trying to delete a UAA user - message #{e.message} trace #{e.backtrace[0..10]}")
      end
    end

    if target_user = ::User.find_by_email(params['email'])

      # Cleanup leftover services
      target_user.service_configs.each { |cfg| cfg.unprovision }

      # Now cleanup any apps we own
      target_user.apps.each do |app|
        if app.owner == target_user
          app.purge_all_resources!
          app.destroy
        end
      end

      target_user.destroy
      render :status => 204, :nothing => true
    else
      raise CloudError.new(CloudError::USER_NOT_FOUND)
    end
  end

  # Change Password
  def update
    if uaa_enabled?
      begin
        user_account = Cloudfoundry::Uaa::UserAccount.new(AppConfig[:uaa][:url], UaaToken.access_token)
        user_account.async = true
        user_account.trace = true
        user_account.logger = CloudController.logger
        user_account.change_password_by_name(user.email, body_params[:password])

      rescue => e
        CloudController.logger.error("Error trying to change the password for a UAA user - message #{e.message} trace #{e.backtrace[0..10]}")
      end
    end

    user.set_and_encrypt_password(body_params[:password])
    user.save!
    render :status => 204, :nothing => true
  end

  def info
    target_user = ::User.find_by_email(params['email'])
    if target_user
      if target_user.email == user.email || @current_user.admin?
        render :json => { :email => target_user.email, :admin => target_user.admin? }
      else
        raise CloudError.new(CloudError::FORBIDDEN)
      end
    else
      raise CloudError.new(CloudError::USER_NOT_FOUND)
    end
  end

  def list
    user_list = User.includes(:apps_owned).all.map do |target_user|
      user_hash = {:email => target_user.email, :admin => target_user.admin?}

      # In the future, more application data could be included here. Keeping it to a minimum for performance
      # in large scale environments. All keys used here should match corresponding keys in App#to_json
      user_hash[:apps] = target_user.apps_owned.map {|app| {:name => app.name, :state => app.state}}
      user_hash
    end

    render :json => user_list
  end

  protected
  def grab_event_user
    @event_args = [ params['email'] || (body_params.nil? ? '' : body_params[:email]) ]
  end

  def enforce_registration_policy
    return if user && user.admin?
    unless AppConfig[:allow_registration]
      CloudController.logger.info("User registration is disabled but someone from #{request.remote_ip} is attempting to register the email '#{body_params[:email]}'.")
      raise CloudError.new(CloudError::FORBIDDEN)
    end
  end
end
