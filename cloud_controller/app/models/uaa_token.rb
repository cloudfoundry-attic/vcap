
require "uaa"
require "uaa/token_decoder"

class UaaToken

  class << self

    def is_uaa_token?(token)
      token.nil? || /\s+/.match(token.strip()).nil?? false : true
    end

    def decode_token(auth_token)
      if (auth_token.nil?)
        return nil
      end

      setup()
      CloudController.logger.debug("uaa token decoder #{@uaa_token_decoder.inspect}")
      CloudController.logger.debug("Auth token is #{auth_token.inspect}")

      token_information = nil
      begin
        token_information = @uaa_token_decoder.decode(auth_token)
        CloudController.logger.info("Token received from the UAA #{token_information.inspect}")
      rescue => e
        CloudController.logger.error("Invalid bearer token Message: #{e.message}")
      end
      return token_information[:email] unless token_information.nil?
    end

    private

    def setup
      @uaa_token_decoder = Cloudfoundry::Uaa::TokenDecoder.new(AppConfig[:uaa][:resource_id],
                                                               AppConfig[:uaa][:token_secret]) unless @uaa_token_decoder
    end

  end

end
