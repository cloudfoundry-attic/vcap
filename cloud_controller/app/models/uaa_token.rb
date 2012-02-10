
require "uaa"
require "uaa/token_decoder"

class UaaToken

  @logger = VCAP::Logging.logger('vcap.uaa_token')
  @uaa_token_decoder = Cloudfoundry::Uaa::TokenDecoder.new(AppConfig[:uaa][:url],
                                                           AppConfig[:uaa][:client_id],
                                                           AppConfig[:uaa][:client_secret])

  class << self

    def is_uaa_token(token)
      /\s+/.match(token.strip()).nil?? false : true
    end

    def get_email(auth_token)
      @logger.debug("UAA decoder information #{@uaa_token_decoder.inspect}")

      token_information = @uaa_token_decoder.decode(auth_token)
      @logger.info("Token received from the UAA #{token_information.inspect}")
      return token_information[:email] unless token_information.nil?
    end

  end

end
