# Copyright (c) 2009-2011 VMware, Inc.
require 'net/http'

require 'services/api/const'
require 'services/api/messages'

module VCAP
  module Services
    module Api
    end
  end
end

class VCAP::Services::Api::ServiceGatewayClient

  class UnexpectedResponse < StandardError
    attr_reader :response

    def initialize(resp)
      @response = resp
    end
  end

  attr_reader :host, :port, :token

  def initialize(host, token, port=80)
    @host  = host
    @port  = port
    @token = token
    @hdrs  = {
      'Content-Type' => 'application/json',
      VCAP::Services::Api::GATEWAY_TOKEN_HEADER => @token
    }
  end

  def provision(args)
    msg = VCAP::Services::Api::GatewayProvisionRequest.new(args)
    resp = perform_request(Net::HTTP::Post, '/gateway/v1/configurations', msg)
    VCAP::Services::Api::GatewayProvisionResponse.decode(resp.body)
  end

  def unprovision(args)
    perform_request(Net::HTTP::Delete, "/gateway/v1/configurations/#{args[:service_id]}")
  end

  def create_snapshot(args)
    resp = perform_request(Net::HTTP::Post, "/gateway/v1/configurations/#{args[:service_id]}/snapshots")
    VCAP::Services::Api::Job.decode(resp.body)
  end

  def enum_snapshots(args)
    resp = perform_request(Net::HTTP::Get, "/gateway/v1/configurations/#{args[:service_id]}/snapshots")
    VCAP::Services::Api::SnapshotList.decode(resp.body)
  end

  def snapshot_details(args)
    resp = perform_request(Net::HTTP::Get, "/gateway/v1/configurations/#{args[:service_id]}/snapshots/#{args[:snapshot_id]}")
    VCAP::Services::Api::Snapshot.decode(resp.body)
  end

  def rollback_snapshot(args)
    resp = perform_request(Net::HTTP::Put, "/gateway/v1/configurations/#{args[:service_id]}/snapshots/#{args[:snapshot_id]}")
    VCAP::Services::Api::Job.decode(resp.body)
  end

  def serialized_url(args)
    resp = perform_request(Net::HTTP::Get, "/gateway/v1/configurations/#{args[:service_id]}/serialized/url")
    VCAP::Services::Api::Job.decode(resp.body)
  end

  def import_from_url(args)
    resp = perform_request(Net::HTTP::Put, "/gateway/v1/configurations/#{args[:service_id]}/serialized/url", args[:msg])
    VCAP::Services::Api::Job.decode(resp.body)
  end

  def import_from_data(args)
    resp = perform_request(Net::HTTP::Put, "/gateway/v1/configurations/#{args[:service_id]}/serialized/data", args[:msg])
    VCAP::Services::Api::Job.decode(resp.body)
  end

  def job_info(args)
    resp = perform_request(Net::HTTP::Get, "/gateway/v1/configurations/#{args[:service_id]}/jobs/#{args[:job_id]}")
    VCAP::Services::Api::Job.decode(resp.body)
  end

  def bind(args)
    msg = VCAP::Services::Api::GatewayBindRequest.new(args)
    resp = perform_request(Net::HTTP::Post, "/gateway/v1/configurations/#{msg.service_id}/handles", msg)
    VCAP::Services::Api::GatewayBindResponse.decode(resp.body)
  end

  def unbind(args)
    msg = VCAP::Services::Api::GatewayUnbindRequest.new(args)
    perform_request(Net::HTTP::Delete, "/gateway/v1/configurations/#{msg.service_id}/handles/#{msg.handle_id}", msg)
  end

  protected

  def perform_request(klass, path, msg=VCAP::Services::Api::EMPTY_REQUEST)
    req = klass.new(path, initheader=@hdrs)
    req.body = msg.encode
    resp = Net::HTTP.new(@host, @port).start {|http| http.request(req)}
    raise UnexpectedResponse, resp unless resp.is_a? Net::HTTPOK
    resp
  end

end
