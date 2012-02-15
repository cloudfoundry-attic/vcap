
require "uaa"
require "uaa/client"

class UaaToken

  @logger = VCAP::Logging.logger('vcap.uaa_token')
  @uaa_client = Cloudfoundry::Uaa::Client.new()

  class << self

    def is_uaa_token(token)
      /\s/.match(token).nil?? false : true
    end

    def get_email(auth_token)
      @uaa_client.target = AppConfig[:uaa][:url] unless(AppConfig[:uaa][:url].nil?)
      @uaa_client.client_id = AppConfig[:uaa][:client_id].to_s unless(AppConfig[:uaa][:client_id].nil?)
      @uaa_client.client_secret = AppConfig[:uaa][:client_secret].to_s unless(AppConfig[:uaa][:client_secret].nil?)
      @logger.debug("UAA Client information #{@uaa_client.inspect}")

      type_token = auth_token.split(' ')
      token = type_token[1]
      token_information = @uaa_client.decode_token(token)
      @logger.info("Token received from the UAA #{token_information.inspect}")
      if(token_information[:resource_ids].include?(:cloud_controller.to_s))
        token_information[:email]
      else
        nil
      end
    end

  end

end
