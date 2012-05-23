# Copyright (c) 2009-2011 VMware, Inc.
require 'net/http'
require 'uri'

require 'services/api/const'
require 'services/api/messages'

module VCAP
  module Services
    module Api
    end
  end
end

module VCAP::Services::Api
  class ServiceGatewayClient
    METHODS_MAP = {
      :get => Net::HTTP::Get,
      :post=> Net::HTTP::Post,
      :put => Net::HTTP::Put,
      :delete => Net::HTTP::Delete,
    }

    # Public: Indicate gateway client encounter an unexpcted error,
    # such as can't connect to gateway or can't decode response.
    #
    class UnexpectedResponse < StandardError; end

    # Pubilc: Indicate an error response from gateway
    #
    class ErrorResponse < StandardError
      attr_reader :status, :error

      # status - the http status
      # error  - a ServiceErrorResponse object
      #
      def initialize(status, error)
        @status = status
        @error = error
      end

      def to_s
        "Reponse status:#{status},error:[#{error.extract}]"
      end
    end

    class NotFoundResponse < ErrorResponse
      def initialize(error)
        super(404, error)
      end
    end

    class GatewayInternalResponse < ErrorResponse
      def initialize(error)
        super(503, error)
      end
    end

    attr_reader :host, :port, :token
    def initialize(url, token, timeout, opts={})
      @url = url
      @timeout = timeout
      @token = token
      @hdrs  = {
        'Content-Type' => 'application/json',
        GATEWAY_TOKEN_HEADER => @token
      }
    end

    def provision(args)
      msg = GatewayProvisionRequest.new(args)
      resp = perform_request(:post, '/gateway/v1/configurations', msg)
      GatewayProvisionResponse.decode(resp)
    end

    def unprovision(args)
      resp = perform_request(:delete, "/gateway/v1/configurations/#{args[:service_id]}")
      EMPTY_REQUEST
    end

    def create_snapshot(args)
      resp = perform_request(:post, "/gateway/v1/configurations/#{args[:service_id]}/snapshots")
      Job.decode(resp)
    end

    def enum_snapshots(args)
      resp = perform_request(:get, "/gateway/v1/configurations/#{args[:service_id]}/snapshots")
      SnapshotList.decode(resp)
    end

    def snapshot_details(args)
      resp = perform_request(:get, "/gateway/v1/configurations/#{args[:service_id]}/snapshots/#{args[:snapshot_id]}")
      Snapshot.decode(resp)
    end

    def rollback_snapshot(args)
      resp = perform_request(:put, "/gateway/v1/configurations/#{args[:service_id]}/snapshots/#{args[:snapshot_id]}")
      Job.decode(resp)
    end

    def delete_snapshot(args)
      resp = perform_request(:delete, "/gateway/v1/configurations/#{args[:service_id]}/snapshots/#{args[:snapshot_id]}")
      Job.decode(resp)
    end

    def create_serialized_url(args)
      resp = perform_request(:post, "/gateway/v1/configurations/#{args[:service_id]}/serialized/url/snapshots/#{args[:snapshot_id]}")
      Job.decode(resp)
    end

    def serialized_url(args)
      resp = perform_request(:get, "/gateway/v1/configurations/#{args[:service_id]}/serialized/url/snapshots/#{args[:snapshot_id]}")
      SerializedURL.decode(resp)
    end

    def import_from_url(args)
      resp = perform_request(:put, "/gateway/v1/configurations/#{args[:service_id]}/serialized/url", args[:msg])
      Job.decode(resp)
    end

    def import_from_data(args)
      resp = perform_request(:put, "/gateway/v1/configurations/#{args[:service_id]}/serialized/data", args[:msg])
      Job.decode(resp)
    end

    def job_info(args)
      resp = perform_request(:get, "/gateway/v1/configurations/#{args[:service_id]}/jobs/#{args[:job_id]}")
      Job.decode(resp)
    end

    def bind(args)
      msg = GatewayBindRequest.new(args)
      resp = perform_request(:post, "/gateway/v1/configurations/#{msg.service_id}/handles", msg)
      GatewayBindResponse.decode(resp)
    end

    def unbind(args)
      msg = GatewayUnbindRequest.new(args)
      perform_request(:delete, "/gateway/v1/configurations/#{msg.service_id}/handles/#{msg.handle_id}", msg)
      EMPTY_REQUEST
    end

    protected

    def perform_request(http_method, path, msg=VCAP::Services::Api::EMPTY_REQUEST)
      result = nil
      uri = URI.parse(@url)
      if EM.reactor_running?
        url = URI.parse(uri.to_s + path)
        http = AsyncHttpRequest.fibered(url, @token, http_method, @timeout, msg)
        raise UnexpectedResponse, "Error sending request #{msg.extract.to_json} to gateway #{@url}: #{http.error}" unless http.error.empty?
        code = http.response_header.status.to_i
        body = http.response
      else
        klass = METHODS_MAP[http_method]
        req = klass.new(path, initheader=@hdrs)
        req.body = msg.encode
        resp = Net::HTTP.new(uri.host, uri.port).start {|http| http.request(req)}
        code = resp.code.to_i
        body = resp.body
      end
      case code
      when 200
        body
      when 404
        err = ServiceErrorResponse.decode(body)
        raise NotFoundResponse.new(err)
      when 503
        err = ServiceErrorResponse.decode(body)
        raise GatewayInternalResponse.new(err)
      else
        begin
          # try to decode the response
          err = ServiceErrorResponse.decode(body)
        rescue => e
          raise UnexpectedResponse, "Can't decode gateway response. status code:#{code}, response body:#{body}"
        end
        raise ErrorResponse.new(code, err)
      end
    end
  end
end
