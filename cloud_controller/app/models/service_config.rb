require 'services/api'

# XXX - Need to move all apps using this config to pending
class ServiceConfig < ActiveRecord::Base
  belongs_to :user    # owner
  belongs_to :service

  has_many :service_bindings, :dependent => :destroy
  has_many :binding_tokens, :dependent => :destroy
  has_many :apps, :through => :service_bindings

  validates_presence_of :alias
  validates_uniqueness_of :alias, :scope => :user_id

  serialize :data
  serialize :credentials

  def self.provision(service, user, cfg_alias, plan, plan_option)

    # Ordering here is important. What follows each numbered operation
    # assumes that it failed.
    #
    # 1. Update the upstream gateway
    #    If the upstream gateway died before provisioning the request,
    #    then no state has changed and all is well. If the upstream died
    #    after provisioning our request, it is responsible for updating
    #    its local state after pulling the canonical state.
    #
    # 2. Update our local state
    #    The upstream is responsible for deleting the dangling config
    #    the next time it pulls canonical state (since the state
    #    will lack the handle).

    begin
      req = VCAP::Services::Api::GatewayProvisionRequest.new(
        :label => service.label,
        :name  => cfg_alias,
        :email => user.email,
        :plan  => plan,
        :plan_option => plan_option
      )

      if EM.reactor_running?
        # yields
        endpoint = "#{service.url}/gateway/v1/configurations"
        http = VCAP::Services::Api::AsyncHttpRequest.fibered(endpoint, service.token, :post, service.timeout, req)
        if !http.error.empty?
          raise "Error sending provision request for #{req.extract.to_json} to gateway #{service.url}: #{http.error}"
        elsif http.response_header.status != 200
          raise "Error sending provision request for #{req.extract.to_json}: non 200 response from gateway #{service.url}: #{http.response_header.status} #{http.response}"
        end
        config = VCAP::Services::Api::GatewayProvisionResponse.decode(http.response)
      else
        uri = URI.parse(service.url)
        gw = VCAP::Services::Api::ServiceGatewayClient.new(uri.host, service.token, uri.port)
        config = gw.provision(req.extract)
      end
    rescue => e
      CloudController.logger.error("Error talking to gateway: #{e}")
      CloudController.logger.error(e)
      raise CloudError.new(CloudError::SERVICE_GATEWAY_ERROR)
    end

    svc_config = ServiceConfig.new(
      :user_id     => user.id,
      :service_id  => service.id,
      :alias       => cfg_alias,
      :data        => config.data,
      :credentials => config.credentials,
      :name        => config.service_id,
      :plan        => plan,
      :plan_option => plan_option
    )
    svc_config.save!

    svc_config
  end

  def unprovision
    svc = service
    cfg_name = name

    # Destroy our copy first. Order here is important. What follows each
    # numbered operation assumes that the operation failed.
    #
    # 1. Destroy the local config
    #    No state (local or upstream) has been altered. All is well.
    #
    # 2. Destroy the remote config
    #    The service provider will be responsible for destroying the remote
    #    config the next time they fetch canonical state.

    destroy

    begin
      if EM.reactor_running?
        endpoint = "#{svc.url}/gateway/v1/configurations/#{cfg_name}"
        http = VCAP::Services::Api::AsyncHttpRequest.new(endpoint, service.token, :delete, service.timeout)
        http.callback do
          if http.response_header.status != 200
            CloudController.logger.error("Error unprovisioning #{cfg_name}, non 200 response from gateway #{svc.url}: #{http.response_header.status} #{http.response}")
          end
        end
        http.errback do
          CloudController.logger.error("Error unprovisioning #{cfg_name} at gateway #{svc.url}: #{http.error}")
        end
      else
        uri = URI.parse(svc.url)
        gw = VCAP::Services::Api::ServiceGatewayClient.new(uri.host, svc.token, uri.port)
        gw.unprovision(:service_id => cfg_name)
      end
    rescue => e
      CloudController.logger.error("Error talking to gateway: #{e}")
      CloudController.logger.error(e)
      raise CloudError.new(CloudError::SERVICE_GATEWAY_ERROR)
    end
  end

  def create_snapshot
    endpoint = "#{service.url}/gateway/v1/configurations/#{name}/snapshots"
    result = perform_gateway_request(:create_snapshot, endpoint, service.token, :post, service.timeout, VCAP::Services::Api::Job, empty_msg_class, :service_id => name)
    result
  end

  def enum_snapshots
    endpoint = "#{service.url}/gateway/v1/configurations/#{name}/snapshots"
    result = perform_gateway_request(:enum_snapshots, endpoint, service.token, :get, service.timeout, VCAP::Services::Api::SnapshotList, empty_msg_class, :service_id => name)
    result
  end

  def snapshot_details(sid)
    endpoint = "#{service.url}/gateway/v1/configurations/#{name}/snapshots/#{sid}"
    result = perform_gateway_request(:snapshot_details, endpoint, service.token, :get, service.timeout, VCAP::Services::Api::Snapshot, empty_msg_class, :service_id => name, :snapshot_id => sid)
    result
  end

  def rollback_snapshot(sid)
    endpoint = "#{service.url}/gateway/v1/configurations/#{name}/snapshots/#{sid}"
    result = perform_gateway_request(:rollback_snapshot, endpoint, service.token, :put, service.timeout, VCAP::Services::Api::Job, empty_msg_class, :service_id => name, :snapshot_id => sid)
    result
  end

  def serialized_url
    endpoint = "#{service.url}/gateway/v1/configurations/#{name}/serialized/url"
    result = perform_gateway_request(:serialized_url, endpoint, service.token, :get, service.timeout, VCAP::Services::Api::Job, empty_msg_class, :service_id => name)
    result
  end

  def import_from_url req
    endpoint = "#{service.url}/gateway/v1/configurations/#{name}/serialized/url"
    result = perform_gateway_request(:import_from_url, endpoint, service.token, :put, service.timeout, VCAP::Services::Api::Job, req, :service_id => name, :msg => req)
    result
  end

  def import_from_data req
    endpoint = "#{service.url}/gateway/v1/configurations/#{name}/serialized/data"
    result = perform_gateway_request(:import_from_data, endpoint, service.token, :put, service.timeout, VCAP::Services::Api::Job, req, :service_id => name, :msg => req)
    result
  end

  def job_info job_id
    endpoint = "#{service.url}/gateway/v1/configurations/#{name}/jobs/#{job_id}"
    result = perform_gateway_request(:job_info, endpoint, service.token, :get, service.timeout, VCAP::Services::Api::Job, empty_msg_class, :service_id => name, :job_id => job_id)
    result
  end

  def empty_msg_class
    VCAP::Services::Api::EMPTY_REQUEST
  end

  # Perform gateway request and decode request to object
  #
  def perform_gateway_request(action, endpoint, token, http_method, timeout, decoder_class, msg, opts={})
    result = nil
    if EM.reactor_running?
      http = VCAP::Services::Api::AsyncHttpRequest.fibered(endpoint, token, http_method, timeout, msg)
      if !http.error.empty?
        raise "Error sending #{action} request for #{name} to gateway #{service.url}: #{http.error}"
      elsif http.response_header.status != 200
        raise "Error sending #{action} request for #{name}: non 200 response from gateway #{service.url}: #{http.response_header.status} #{http.response}"
      end
      result = decoder_class.decode(http.response)
    else
      uri = URI.parse(endpoint)
      gw = VCAP::Services::Api::ServiceGatewayClient.new(uri.host, token, uri.port)
      result = gw.send(action, opts)
    end
    result.extract
  rescue => e
    CloudController.logger.error("Error talking to gateway: #{e}")
    CloudController.logger.error(e)
    raise CloudError.new(CloudError::SERVICE_GATEWAY_ERROR)
  end

  def provisioned_by?(user)
    (self.user_id == user.id)
  end

  # Returned for calls from legacy clients
  def as_legacy
    { :name       => self.alias,
      :type       => self.service.synthesize_service_type,
      :vendor     => self.service.name,
      :version    => self.service.version,
      :tier       => self.plan,
      :properties => self.service.binding_options || {},
      :meta => {
        :created => self.created_at.to_i,
        :updated => self.updated_at.to_i,
        :tags    => self.service.tags || [],
        :version => 1 # This no longer exists, just here for completeness
      },
    }
  end
end
