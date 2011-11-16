class UserTokensController < ApplicationController

  def create
    email = params['email']
    password = body_params[:password]
    if ::User.valid_login?(email, password) || (@current_user && @current_user.admin?)
      # This could just check the ::User.admins variable, but using this method to support changes in admin? in the future
      user = ::User.find_by_email(email)
      if AppConfig[:https_required] or (user.admin? and AppConfig[:https_required_for_admins])
        CloudController.logger.error("Authentication failure: #{auth_token_header.inspect}", :tags => [:auth_failure])
        raise CloudError.new(CloudError::HTTPS_REQUIRED) unless request_https?
      end

      token = UserToken.create(email)
      render :json => token
    else
      raise CloudError.new(CloudError::FORBIDDEN)
    end
  end
end
