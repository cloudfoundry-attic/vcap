
require "uaa"
require "uaa/token_decoder"

class UaaToken

  @logger = VCAP::Logging.logger('vcap.uaa_token')

  class << self

    def is_uaa_token?(token)
      token.nil? || /\s+/.match(token.strip()).nil?? false : true
    end

    def decode_token(auth_token)
      if (auth_token.nil?)
        return nil
      end

      setup()
      @logger.debug("uaa token decoder #{@uaa_token_decoder.inspect}")
      @logger.debug("Auth token is #{auth_token.inspect}")

      token_information = nil
      begin
        token_information = @uaa_token_decoder.decode(auth_token)
        @logger.info("Token received from the UAA #{token_information.inspect}")
      rescue => e
        @logger.error("Invalid bearer token Message: #{e.message}")
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
