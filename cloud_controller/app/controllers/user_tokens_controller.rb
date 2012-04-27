class UserTokensController < ApplicationController

  def create
    email = params['email']
    CloudController.logger.debug("Login request from #{email}")
    password = body_params[:password]
    if ::User.valid_login?(email, password) || (@current_user && @current_user.admin?)
      # This could just check the ::User.admins variable, but using this method to support changes in admin? in the future
      user = ::User.find_by_email(email)
      if AppConfig[:https_required] or (user.admin? and AppConfig[:https_required_for_admins])
        CloudController.logger.error("Authentication failure: #{auth_token_header.inspect}", :tags => [:auth_failure])
        raise CloudError.new(CloudError::HTTPS_REQUIRED) unless request_https?
      end

      token = nil
      if uaa_enabled?
        begin
          email_filter = AppConfig[:uaa][:token_creation_email_filter]
          if !email_filter.nil? && email_filter.kind_of?(Array) && email_filter.size() > 0
            # We would like to have a filter like "vmware.com$|emc.com$"
            match_phrase = email_filter.size() == 1 ? "#{email_filter[0]}$" : email_filter.reduce{|e, n| e.end_with?("$") ? "#{e}|#{n}$" : "#{e}$|#{n}$"}
            unless email.match(match_phrase).nil?
              # Call the uaa to issue a token
              token = Yajl::Encoder.encode({"token" => UaaToken.id_token(email, password)})
            end
          end
        rescue => e
          CloudController.logger.error("Failed to fetch a login token from the uaa. email #{email} #{e.message}")
          # Swallow the exception. If the token fetch from the uaa fails, return the old style token
        end
      end

      if token.nil?
        token = UserToken.create(email)
      end
      CloudController.logger.debug("Login request from #{email} token #{token.inspect}")
      render :json => token
    else
      raise CloudError.new(CloudError::FORBIDDEN)
    end
  end
end
