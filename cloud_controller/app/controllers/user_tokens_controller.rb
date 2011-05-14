class UserTokensController < ApplicationController
  skip_before_filter :fetch_user_from_token, :only => :create

  def create
    email = params['email']
    password = body_params[:password]
    if ::User.valid_login?(email, password)
      # This could just check the ::User.admins variable, but using this method to support changes in admin? in the future 
      user = ::User.find_by_email(email)
      if AppConfig[:https_required] or (user.admin? and AppConfig[:https_required_for_admins])
        raise CloudError.new(CloudError::HTTPS_REQUIRED) unless !request.headers["X-Forwarded_Proto"].nil? and request.headers["X-Forwarded_Proto"] =~ /^https/i
      end
      
      token = UserToken.create(email)
      render :json => token
    else
      raise CloudError.new(CloudError::FORBIDDEN)
    end
  end
end
