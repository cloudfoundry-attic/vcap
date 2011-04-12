class UserTokensController < ApplicationController
  skip_before_filter :fetch_user_from_token, :only => :create

  def create
    email = params['email']
    password = body_params[:password]
    if ::User.valid_login?(email, password)
      token = UserToken.create(email)
      render :json => token
    else
      raise CloudError.new(CloudError::FORBIDDEN)
    end
  end
end
