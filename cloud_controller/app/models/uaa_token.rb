
require "uaa"
require "uaa/client"

class UaaToken

  @logger = VCAP::Logging.logger('vcap.uaa_token')
  @uaa_client = Cloudfoundry::Uaa::Client.new()

  def initialize
    unless(AppConfig[:uaa_url].nil?)
      @uaa_client.target_url = AppConfig[:uaa_url]
    end
  end

  class << self

    def is_uaa_token(token)
      /^([Bb]earer )/.match(token).nil?? false : true
    end

    def get_token_information(token)
      client_authentication_opts = {:client_id => "app", :client_secret => "appclientsecret" }
      @logger.info("#{@uaa_client.inspect}")
      @uaa_client.decode_token(token, client_authentication_opts)
    end

  end

end
