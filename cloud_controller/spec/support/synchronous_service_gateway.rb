$:.unshift(File.expand_path("../../../lib", __FILE__))
require 'rubygems'

require 'json'
require 'sinatra/base'
require 'uri'
require 'thread'

require 'json_message'
require 'services/api'

module VCAP
  module Services
  end
end

class VCAP::Services::SynchronousServiceGateway < Sinatra::Base
  REQ_OPTS            = %w(service token provisioner).map {|o| o.to_sym}
  SERVICE_UNAVAILABLE = [503, {'Content-Type' => Rack::Mime.mime_type('.json')}, '{}']
  NOT_FOUND           = [404, {'Content-Type' => Rack::Mime.mime_type('.json')}, '{}']
  UNAUTHORIZED        = [401, {'Content-Type' => Rack::Mime.mime_type('.json')}, '{}']

  # Allow our exception handlers to take over
  set :raise_errors, Proc.new {false}
  set :show_exceptions, false

  def initialize(opts)
    super
    missing_opts = REQ_OPTS.select {|o| !opts.has_key? o}
    raise ArgumentError, "Missing options: #{missing_opts.join(', ')}" unless missing_opts.empty?
    @service = opts[:service]
    @token   = opts[:token]
    @logger  = opts[:logger] || make_logger()
    @provisioner = opts[:provisioner]
  end


  # Validate the incoming request
  before do
    abort_request('headers' => 'Invalid Content-Type') unless request.media_type == Rack::Mime.mime_type('.json')
    halt(*UNAUTHORIZED) unless auth_token && (auth_token == @token)
    content_type :json
  end

  # Handle errors that result from malformed requests
  error [JsonMessage::ValidationError, JsonMessage::ParseError] do
    abort_request(request.env['sinatra.error'].to_s)
  end

  #################### Handlers ####################

  # Provisions an instance of the service
  #
  post '/gateway/v1/configurations' do
    req = VCAP::Services::Api::GatewayProvisionRequest.decode(request_body)

    @logger.debug("Provision request for label=#{req.label} plan=#{req.plan}")

    name, version = VCAP::Services::Api::Util.parse_label(req.label)
    unless (name == @service[:name]) && (version == @service[:version])
      @logger.debug("Unknown label #{req.label}, #{@service.inspect}")
      abort_request('Unknown label')
    end

    svc = @provisioner.provision_service(version, req.plan)
    if svc
      VCAP::Services::Api::GatewayProvisionResponse.new(svc).encode
    else
      SERVICE_UNAVAILABLE
    end
  end

  # Unprovisions a previously provisioned instance of the service
  #
  delete '/gateway/v1/configurations/:service_id' do
    @logger.debug("Unprovision request for service_id=#{params['service_id']}")

    if @provisioner.unprovision_service(params['service_id'])
      200
    else
      NOT_FOUND
    end
  end

  # Binds a previously provisioned instance of the service to an application
  #
  post '/gateway/v1/configurations/:service_id/handles' do
    req = VCAP::Services::Api::GatewayBindRequest.decode(request_body)

    handle = @provisioner.bind_instance(req.service_id, req.binding_options)
    if handle
      VCAP::Services::Api::GatewayBindResponse.new(handle).encode
    else
      NOT_FOUND
    end
  end

  # Unbinds a previously bound instance of the service
  #
  delete '/gateway/v1/configurations/:service_id/handles/:handle_id' do
    req = VCAP::Services::Api::GatewayUnbindRequest.decode(request_body)
    success = @provisioner.unbind_instance(req.service_id, req.handle_id, req.binding_options)
    (success ? 200 : NOT_FOUND)
  end

  #################### Helpers ####################

  helpers do

    # Aborts the request with the supplied errs
    #
    # +errs+  Hash of section => err
    def abort_request(errs)
      err_body = {'errors' => errs}.to_json()
      halt(410, {'Content-Type' => Rack::Mime.mime_type('.json')}, err_body)
    end

    def auth_token
      @auth_token ||= request_header(VCAP::Services::Api::GATEWAY_TOKEN_HEADER)
      @auth_token
    end

    def request_body
      request.body.rewind
      request.body.read
    end

    def request_header(header)
      # This is pretty ghetto but Rack munges headers, so we need to munge them as well
      rack_hdr = "HTTP_" + header.upcase.gsub(/-/, '_')
      env[rack_hdr]
    end
  end

  private

  def make_logger()
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG
    logger
  end
end
