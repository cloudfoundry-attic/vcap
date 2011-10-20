require 'net/http'
require 'yajl'

module VCAP
  module CloudController
    module Ipc
    end
  end
end

class VCAP::CloudController::Ipc::ServiceConsumerV1Client
  attr_reader :host
  attr_reader :port

  def initialize(host, port, opts={})
    @host = host
    @port = port
    @headers = {'Content-Type' => 'application/json'}
    @headers['X-VCAP-Staging-Task-ID'] = opts[:staging_task_id] if opts[:staging_task_id]
  end

  def provision_service(label, name, plan, plan_option=nil)
    body_hash = {
      :label => label,
      :name  => name,
      :plan  => plan,
      :plan_option => plan_option,
    }
    perform_request(Net::HTTP::Post, '/services/v1/configurations', body_hash)
  end

  def unprovision_service(name)
    perform_request(Net::HTTP::Delete, "/services/v1/configurations/#{name}")
  end

  protected

  def perform_request(net_http_class, path, body_hash=nil)
    req = net_http_class.new(path, initheaders=@headers)
    req.body = Yajl::Encoder.encode(body_hash) if body_hash
    resp = Net::HTTP.new(@host, @port).start {|http| http.request(req) }
    if resp.kind_of?(Net::HTTPSuccess)
      {:result => Yajl::Parser.parse(resp.body)}
    else
      {:error  => resp}
    end
  end
end
