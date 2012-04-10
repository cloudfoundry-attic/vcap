require 'legacy_vmc_messages'
require 'services/api'

class LegacyServicesController < ApplicationController
  include ServicesHelper

  rescue_from(JsonMessage::Error) {|e| render :status => 400, :json =>  {:description => e.to_s}}
  rescue_from(ActiveRecord::RecordInvalid) {|e| render :status => 400, :json =>  {:description => e.to_s}}

  before_filter :require_user

  # Lists all services the user has provisioned
  #
  def list
    CloudController.logger.debug("Getting all provisioned services for user: #{user.id}")

    cfgs = ServiceConfig.find_all_by_user_id(user.id)
    CloudController.logger.debug("Found #{cfgs.length} provisioned services for user: #{user.id}")
    ret = cfgs.map {|cfg| cfg.as_legacy}
    CloudController.logger.debug("Returning configs: #{ret.inspect}")

    render :json => ret
  end

  # Gets specific info
  #
  def get
    CloudController.logger.debug("Getting info for provisioned service with name: #{params[:alias]}")

    cfg = ServiceConfig.find_by_alias_and_user_id(params[:alias], user.id)
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    CloudController.logger.debug("Returning config: #{cfg.as_legacy.inspect}")

    render :json => cfg.as_legacy
  end

  # Provision an instance of an existing service
  #
  def provision
    CloudController.logger.debug("Attempting to provision service: #{request_body}")

    limit = user.account_capacity[:services]
    used  = user.account_usage[:services]

    if (used >= limit)
      raise CloudError.new(CloudError::ACCOUNT_TOO_MANY_SERVICES, used, limit)
    end

    req = LegacyVmcMessages::ProvisionRequest.decode(request_body)
    @event_args = [req.vendor, req.name]

    label = req.vendor + "-" + req.version
    svc = ::Service.find_by_label(label)
    # Legacy api fell back to matching by vendor if no version matched
    svc ||= ::Service.find_by_name(req.vendor)

    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless svc && svc.visible_to_user?(user, req.tier)

    plan_option = nil
    if req.options && req.options['plan_option']
      plan_option = req.options['plan_option']
    end
    ServiceConfig.provision(svc, user, req.name, req.tier, plan_option)

    render :json => {}
  end

  # Unprovision an instance
  def unprovision
    CloudController.logger.debug("Attempting to unprovision service: #{request_body}")

    cfg = ServiceConfig.find_by_user_id_and_alias(user.id, params[:alias])
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    raise CloudError.new(CloudError::FORBIDDEN) unless cfg.provisioned_by?(user)
    @event_args = [ cfg[:service_id], cfg[:name] ]

    cfg.unprovision

    render :json => {}
  end
end
