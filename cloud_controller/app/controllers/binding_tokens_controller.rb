require 'json_message'
require 'services/api'

class BindingTokensController < ApplicationController
  before_filter :validate_content_type
  before_filter :require_user, :only => [:create, :delete]

  rescue_from(JsonMessage::Error) {|e| render :status => 400, :json =>  {:errors => e.to_s}}
  rescue_from(ActiveRecord::RecordInvalid) {|e| render :status => 400, :json =>  {:errors => e.to_s}}

  # Creates a binding token that can be redeemed in order to bind to the
  # service in the token
  def create
    req = VCAP::Services::Api::BindingTokenRequest.decode(request_body)

    cfg = ServiceConfig.find_by_name(req.service_id)
    raise CloudError.new(CloudError::SERVICE_NOT_FOUND) unless cfg
    raise CloudError.new(CloudError::FORBIDDEN) unless cfg.user_id == user.id

    tok = ::BindingToken.generate(
      :label => cfg.service.label,
      :service_config  => cfg,
      :binding_options => req.binding_options
    )
    tok.save!

    resp = {
      :label => tok.label,
      :binding_token => tok.uuid
    }
    render_ok resp
  end

  # Retrieves the original contents of a binding token
  def get
    tok = ::BindingToken.find_by_uuid(params[:binding_token])
    raise CloudError.new(CloudError::TOKEN_NOT_FOUND) unless tok
    ret = {
      :service_id => tok.service_config.name,
      :binding_options => tok.binding_options
    }
    render_ok ret
  end

  # Deletes a binding token and all associated bindings. Note that the upstream
  # will be responsible for updating its state to reflect the deleted bindings
  # the next time it fetches the canonical state.
  def delete
    tok = ::BindingToken.find_by_uuid(params[:binding_token])
    raise CloudError.new(CloudError::TOKEN_NOT_FOUND) unless tok
    raise CloudError.new(CloudError::FORBIDDEN) unless tok.service_config.user_id == user.id

    tok.destroy

    render_ok
  end

  protected

  def render_ok(body={})
    render :status => 200, :json => body
  end

  def validate_content_type
    raise CloudError.new(CloudError::BAD_REQUEST) unless request.env['CONTENT_TYPE'] == Mime::JSON
  end

end
