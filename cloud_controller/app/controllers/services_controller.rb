require 'json_message'
require 'services/api'

# TODO(mjp): Split these into separate controllers (user facing vs gateway facing, along with tests)

class ServicesController < ApplicationController
  include ServicesHelper

  before_filter :validate_content_type
  before_filter :require_service_auth_token, :only => [:create, :delete, :update_handle, :list_handles, :list_brokered_services]
  before_filter :require_user, :only => [:provision, :bind, :bind_external, :unbind, :unprovision,
                                         :create_snapshot, :enum_snapshots, :snapshot_details,:rollback_snapshot,
                                         :serialized_url, :import_from_url, :import_from_data, :job_info]
  before_filter :require_lifecycle_extension, :only => [:create_snapshot, :enum_snapshots, :snapshot_details,:rollback_snapshot,
                                         :serialized_url, :import_from_url, :import_from_data, :job_info]

  rescue_from(JsonMessage::Error) {|e| render :status => 400, :json =>  {:errors => e.to_s}}
  rescue_from(ActiveRecord::RecordInvalid) {|e| render :status => 400, :json =>  {:errors => e.to_s}}

  # Registers a new service offering with the CC
  #
  def create
    req = VCAP::Services::Api::ServiceOfferingRequest.decode(request_body)
    CloudController.logger.debug("Create service request: #{req.extract.inspect}")

    # Should we worry about a race here?

    success = nil
    svc = Service.find_by_label(req.label)
    if svc
      raise CloudError.new(CloudError::FORBIDDEN) unless svc.verify_auth_token(@service_auth_token)
      attrs = req.extract.dup
      attrs.delete(:label)
      # Keep DB in sync with configs if the token changes in the config
      attrs[:token] = @service_auth_token if svc.is_builtin?
      # Special support for changing a service offering's ACLs from
      # private to public. The call to ServiceOfferingRequest.decode
      # (actually, JsonMessage.from_decoded_json) discards keys with
      # nil values, which is the case for key :acls when switching
      # from private to public.  This issue is more general than just
      # :acls, but to avoid breaking anything as a side efffect, we do
      # this only for :acls.
      attrs[:acls] = nil unless attrs.has_key?(:acls)

      # Similar to acls, do the same for timeout
      attrs[:timeout] = nil unless attrs.has_key?(:timeout)

      svc.update_attributes!(attrs)
    else
      # Service doesn't exist yet. This can only happen for builtin services since service providers must
      # register with us to get a token.
      # or, it's a brokered service
      svc = Service.new(req.extract)
      if AppConfig[:service_broker] and @service_auth_token == AppConfig[:service_broker][:token] and !svc.is_builtin?
        attrs = req.extract.dup
        attrs[:token] = @service_auth_token
        svc.update_attributes!(attrs)
      else
        raise CloudError.new(CloudError::FORBIDDEN) unless svc.is_builtin? && svc.verify_auth_token(@service_auth_token)
        svc.token = @service_auth_token
        svc.save!
      end
    end

    render :json => {}
  end

  # Updates given handle with the new config.
  # XXX: This is REALLY inefficient...
  #
  def update_handle
    handle = VCAP::Services::Api::HandleUpdateRequest.decode(request_body)

    # We have to check two places here: configs and bindings :/
    if cfg = ServiceConfig.find_by_name(handle.service_id)
      raise CloudError.new(CloudError::FORBIDDEN) unless cfg.service.verify_auth_token(@service_auth_token)
      cfg.data = handle.configuration
      cfg.credentials = handle.credentials
      cfg.save!
    elsif bdg = ServiceBinding.find_by_name(handle.service_id)
      svc = bdg.service_config.service
      raise CloudError.new(CloudError::FORBIDDEN) unless (svc && (svc.verify_auth_token(@service_auth_token)))
      bdg.configuration = handle.configuration
      bdg.credentials = handle.credentials
      bdg.save!
    end

    raise CloudError.new(CloudError::BINDING_NOT_FOUND) unless (cfg || bdg)

    render :json => {}
  end

  # Returns the provisioned and bound handles for a service provider
  def list_handles
    svc = Service.find_by_label(params[:label])
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless svc
    raise CloudError.new(CloudError::FORBIDDEN) unless svc.verify_auth_token(@service_auth_token)

    handles = []
    cfgs = svc.service_configs
    if cfgs
      cfgs.each do |cfg|
        handles << {
          :service_id => cfg.name,
          :configuration => cfg.data,
          :credentials   => cfg.credentials
        }
      end
    end

    bdgs = svc.service_bindings
    if bdgs
      bdgs.each do |bdg|
        handles << {
          :service_id => bdg.name,
          :configuration => bdg.configuration,
          :credentials   => bdg.credentials,
        }
      end
    end

    render :json => {:handles => handles}
  end

  # List brokered services
  def list_brokered_services
    if AppConfig[:service_broker].nil? or @service_auth_token != AppConfig[:service_broker][:token]
      raise CloudError.new(CloudError::FORBIDDEN)
    end

    svcs = Service.all
    brokered_svcs = svcs.select {|svc| ! svc.is_builtin? }
    result = []
    brokered_svcs.each do |svc|
      result << {
        :label => svc.label,
        :description => svc.description,
        :acls => svc.acls,
      }
    end
    render :json =>  {:brokered_services => result}
  end

  # Unregister a service offering with the CC
  #
  def delete
    svc = Service.find_by_label(params[:label])
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless svc
    raise CloudError.new(CloudError::FORBIDDEN) unless svc.verify_auth_token(@service_auth_token)

    svc.destroy

    render :json => {}
  end

  # Asks the gateway to provision an instance of the requested service
  #
  def provision
    req = VCAP::Services::Api::CloudControllerProvisionRequest.decode(request_body)

    svc = Service.find_by_label(req.label)
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless svc && svc.visible_to_user?(user)

    cfg = ServiceConfig.provision(svc, user, req.name, req.plan, req.plan_option)

    handle = {
      :service_id  => cfg.name,
      :data        => cfg.data,
      :credentials => cfg.credentials,
    }
    render :json => handle
  end

  # Deletes a previously provisioned instance of a service
  #
  def unprovision
    cfg = ServiceConfig.find_by_user_id_and_name(user.id, params['id'])
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    raise CloudError.new(CloudError::FORBIDDEN) unless cfg.provisioned_by?(user)

    cfg.unprovision

    render :json => {}
  end

  # Create a snapshot for service instance
  #
  def create_snapshot
    cfg = ServiceConfig.find_by_user_id_and_name(user.id, params['id'])
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    raise CloudError.new(CloudError::FORBIDDEN) unless cfg.provisioned_by?(user)

    result = cfg.create_snapshot

    render :json => result
  end

  # Enumerate all snapshots of the given instance
  #
  def enum_snapshots
    cfg = ServiceConfig.find_by_user_id_and_name(user.id, params['id'])
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    raise CloudError.new(CloudError::FORBIDDEN) unless cfg.provisioned_by?(user)

    result = cfg.enum_snapshots

    render :json => result
  end

  # Get snapshot detail information
  #
  def snapshot_details
    cfg = ServiceConfig.find_by_user_id_and_name(user.id, params['id'])
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    raise CloudError.new(CloudError::FORBIDDEN) unless cfg.provisioned_by?(user)

    result = cfg.snapshot_details params['sid']

    render :json => result
  end

  # Rollback to a snapshot
  #
  def rollback_snapshot
    cfg = ServiceConfig.find_by_user_id_and_name(user.id, params['id'])
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    raise CloudError.new(CloudError::FORBIDDEN) unless cfg.provisioned_by?(user)

    result = cfg.rollback_snapshot params['sid']

    render :json => result
  end

  # Get the url to download serialized data for an instance
  #
  def serialized_url
    cfg = ServiceConfig.find_by_user_id_and_name(user.id, params['id'])
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    raise CloudError.new(CloudError::FORBIDDEN) unless cfg.provisioned_by?(user)

    result = cfg.serialized_url

    render :json => result
  end

  # import serialized data to an instance from url
  #
  def import_from_url
    req = VCAP::Services::Api::SerializedURL.decode(request_body)

    cfg = ServiceConfig.find_by_user_id_and_name(user.id, params['id'])
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    raise CloudError.new(CloudError::FORBIDDEN) unless cfg.provisioned_by?(user)

    result = cfg.import_from_url req

    render :json => result
  end

  # import serialized data to an instance from request data
  #
  def import_from_data
    max_upload_size = AppConfig[:service_lifecycle][:max_upload_size] || 1
    max_upload_size = max_upload_size * 1024 * 1024
    raise CloudError.new(CloudError::BAD_REQUEST) unless request.content_length < max_upload_size

    req = VCAP::Services::Api::SerializedData.decode(request_body)

    cfg = ServiceConfig.find_by_user_id_and_name(user.id, params['id'])
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    raise CloudError.new(CloudError::FORBIDDEN) unless cfg.provisioned_by?(user)

    result = cfg.import_from_data req

    render :json => result
  end

  # Get job information
  #
  def job_info
    cfg = ServiceConfig.find_by_user_id_and_name(user.id, params['id'])
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    raise CloudError.new(CloudError::FORBIDDEN) unless cfg.provisioned_by?(user)

    result = cfg.job_info params['job_id']

    render :json => result
  end

  # Binds a provisioned instance to an app
  #
  def bind
    req = VCAP::Services::Api::CloudControllerBindRequest.decode(request_body)

    app = ::App.find_by_collaborator_and_id(user, req.app_id)
    raise CloudError.new(CloudError::APP_NOT_FOUND) unless app

    cfg = ServiceConfig.find_by_name(req.service_id)
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    raise CloudError.new(CloudError::FORBIDDEN) unless cfg.provisioned_by?(user)

    binding = app.bind_to_config(cfg)

    resp = {
      :binding_token => binding.binding_token.uuid,
      :label => cfg.service.label
    }
    render :json => resp
  end

  # Binds an app to a service using an existing binding token
  #
  def bind_external
    cli_req = VCAP::Services::Api::BindExternalRequest.decode(request_body)

    app = ::App.find_by_collaborator_and_id(user, cli_req.app_id)
    raise CloudError.new(CloudError::APP_NOT_FOUND) unless app

    tok = ::BindingToken.find_by_uuid(cli_req.binding_token)
    raise CloudError.new(CloudError::TOKEN_NOT_FOUND) unless tok

    cfg = tok.service_config
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg

    app.bind_to_config(cfg, tok.binding_options)

    render :json => {}
  end

  # Unbinds a previously bound instance from an app
  #
  def unbind
    tok = ::BindingToken.find_by_uuid(params['binding_token'])
    raise CloudError.new(CloudError::BINDING_NOT_FOUND) unless tok

    # It's possible that a previous attempt at binding failed, leaving a dangling token.
    # In this case just log the issue and clean up.

    binding = ServiceBinding.find_by_binding_token_id(tok.id)
    unless binding
      CloudController.logger.info("Removing dangling token #{tok.uuid}")
      CloudController.logger.info(tok.inspect)
      tok.destroy
      render :json => {}
      return
    end

    app = binding.app
    svc_config = binding.service_config
    app.unbind_from_config(svc_config)

    render :json => {}
  end

  protected

  def require_service_auth_token
    hdr = VCAP::Services::Api::GATEWAY_TOKEN_HEADER.upcase.gsub(/-/, '_')
    @service_auth_token = request.headers[hdr]
    raise CloudError.new(CloudError::FORBIDDEN) unless @service_auth_token
  end

  def require_lifecycle_extension
    raise CloudError.new(CloudError::EXTENSION_NOT_IMPL, "lifecycle") unless AppConfig.has_key?(:service_lifecycle)
  end
end
