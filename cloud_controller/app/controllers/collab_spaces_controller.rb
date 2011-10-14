class CollabSpacesController < ApplicationController
  before_filter :enforce_registration_policy, :only => :create
  before_filter :require_admin, :only => [:delete, :list]

  # POST to /orgs/:org
  def create

    new_organization_name = params[:org]

    org_manager = CollabSpaces::OrganizationManager.new

    immutable_id = org_manager.create_organization(new_organization_name)

    render :json => {:result => 'success',  :id => immutable_id }

  end

  # DELETE to /orgs/:org
  def delete

    new_organization_name = params[:org]

    org_manager = CollabSpaces::OrganizationManager.new

    if(org_manager.delete_organization(new_organization_name))
      render :json => {:result => 'success'}
    else
      raise CloudError.new(CloudError::DATABASE_ERROR)
    end

  end

  def require_admin
    unless user && user.admin?
      CloudController.logger.warn("Authentication failure: #{auth_token_header.inspect}", :tags => [:auth_failure])
      raise CloudError.new(CloudError::FORBIDDEN)
    end
  end

  def enforce_registration_policy
    return if user && user.admin?
    if AppConfig[:local_register_only] && remote_request?
      raise CloudError.new(CloudError::FORBIDDEN)
    end
  end

end
