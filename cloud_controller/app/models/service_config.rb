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

      client = VCAP::Services::Api::ServiceGatewayClient.new(service.url, service.token, service.timeout)
      config = client.provision req.extract
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
      client = VCAP::Services::Api::ServiceGatewayClient.new(service.url, service.token, service.timeout)
      client.unprovision(:service_id => cfg_name)
    rescue => e
      CloudController.logger.error("Error talking to gateway: #{e}")
      CloudController.logger.error(e)
      raise CloudError.new(CloudError::SERVICE_GATEWAY_ERROR)
    end
  end

  def handle_lifecycle_error(e)
    CloudController.logger.error("Error talking to gateway: #{e}")
    CloudController.logger.error(e)
    if e.is_a? VCAP::Services::Api::ServiceGatewayClient::ErrorResponse
      raise CloudError.new([e.error.code, e.status, e.error.description])
    else
      raise CloudError.new(CloudError::SERVICE_GATEWAY_ERROR)
    end
  end

  def create_snapshot
    client = VCAP::Services::Api::ServiceGatewayClient.new(service.url, service.token, service.timeout)
    client.create_snapshot(:service_id => name)
  rescue => e
    handle_lifecycle_error(e)
  end

  def enum_snapshots
    client = VCAP::Services::Api::ServiceGatewayClient.new(service.url, service.token, service.timeout)
    client.enum_snapshots(:service_id => name)
  rescue => e
    handle_lifecycle_error(e)
  end

  def snapshot_details(sid)
    client = VCAP::Services::Api::ServiceGatewayClient.new(service.url, service.token, service.timeout)
    client.snapshot_details(:service_id => name, :snapshot_id => sid)
  rescue => e
    handle_lifecycle_error(e)
  end

  def rollback_snapshot(sid)
    client = VCAP::Services::Api::ServiceGatewayClient.new(service.url, service.token, service.timeout)
    client.rollback_snapshot(:service_id => name, :snapshot_id => sid)
  rescue => e
    handle_lifecycle_error(e)
  end

  def delete_snapshot(sid)
    client = VCAP::Services::Api::ServiceGatewayClient.new(service.url, service.token, service.timeout)
    client.delete_snapshot(:service_id => name, :snapshot_id => sid)
  rescue => e
    handle_lifecycle_error(e)
  end

  def serialized_url(sid)
    client = VCAP::Services::Api::ServiceGatewayClient.new(service.url, service.token, service.timeout)
    client.serialized_url(:service_id => name, :snapshot_id => sid)
  rescue => e
    handle_lifecycle_error(e)
  end

  def create_serialized_url(sid)
    client = VCAP::Services::Api::ServiceGatewayClient.new(service.url, service.token, service.timeout)
    client.create_serialized_url(:service_id => name, :snapshot_id => sid)
  rescue => e
    handle_lifecycle_error(e)
  end

  def import_from_url req
    client = VCAP::Services::Api::ServiceGatewayClient.new(service.url, service.token, service.timeout)
    client.import_from_url(:service_id => name, :msg => req)
  rescue => e
    handle_lifecycle_error(e)
  end

  def import_from_data req
    client = VCAP::Services::Api::ServiceGatewayClient.new(service.url, service.token, service.timeout)
    client.import_from_data(:service_id => name, :msg => req)
  rescue => e
    handle_lifecycle_error(e)
  end

  def job_info job_id
    client = VCAP::Services::Api::ServiceGatewayClient.new(service.url, service.token, service.timeout)
    client.job_info(:service_id => name, :job_id => job_id)
  rescue => e
    handle_lifecycle_error(e)
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
