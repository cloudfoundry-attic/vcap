
require "uaa/token_coder"

class UaaToken

  @uaa_token_coder ||= Cloudfoundry::Uaa::TokenCoder.new(AppConfig[:uaa][:resource_id],
                                                         AppConfig[:uaa][:token_secret])
  class << self

    def is_uaa_token?(token)
      token.nil? || /\s+/.match(token.strip()).nil?? false : true
    end

    def decode_token(auth_token)
      if (auth_token.nil?)
        return nil
      end

      CloudController.logger.debug("uaa token coder #{@uaa_token_coder.inspect}")
      CloudController.logger.debug("Auth token is #{auth_token.inspect}")

      token_information = nil
      begin
        token_information = @uaa_token_coder.decode(auth_token)
        CloudController.logger.info("Token received from the UAA #{token_information.inspect}")
      rescue => e
        CloudController.logger.error("Invalid bearer token Message: #{e.message}")
      end
      token_information[:email] if token_information
    end

  end

end
