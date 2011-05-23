class UsersController < ApplicationController
  before_filter :enforce_registration_policy, :only => :create
  before_filter :grab_event_user
  before_filter :require_user, :except => :create
  before_filter :require_admin, :only => :delete

  def create
    user = ::User.new :email => body_params[:email]
    user.set_and_encrypt_password(body_params[:password])

    if user.save
      render :status => 204, :nothing => true
    else
      raise CloudError.new(CloudError::BAD_REQUEST)
    end
  end

  def delete
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
    user.set_and_encrypt_password(body_params[:password])
    user.save!
    render :status => 204, :nothing => true
  end

  def info
    # FIXME, make sure request matches logged in user!
    render :json => { :email => user.email }
  end

  protected
  def grab_event_user
    @event_args = [ params['email'] || body_params[:email] ]
  end

  def enforce_registration_policy
    return if user && user.admin?
    if AppConfig[:local_register_only] && remote_request?
      raise CloudError.new(CloudError::FORBIDDEN)
    end
  end
end
