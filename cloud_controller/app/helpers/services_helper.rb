module ServicesHelper

  def validate_content_type
    raise CloudError.new(CloudError::BAD_REQUEST) unless request.env['CONTENT_TYPE'] == Mime::JSON
  end

  def gateway_client(svc)
    uri = URI.parse(svc.url)
    VCAP::Services::Api::ServiceGatewayClient.new(uri.host, svc.token, uri.port)
  end

  def gateway_request(&blk)
    begin
      yield
    rescue VCAP::Services::Api::ServiceGatewayClient::UnexpectedResponse,  \
           SocketError,                                                    \
           Errno::ECONNREFUSED,                                            \
           Errno::ECONNRESET,                                              \
           Errno::ETIMEDOUT => e
      logger.error "Error talking to gateway: #{e.to_s}"
      raise CloudError.new(CloudError::SERVICE_GATEWAY_ERROR)
    end
  end

end
