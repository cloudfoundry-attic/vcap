class ResourcePoolController < ApplicationController
  before_filter :require_user

  # TODO - Do we need to complain about dumb requests?
  # Currently we just say nothing matched and move on.
  def match
    descriptors = body_params
    matched = CloudController.resource_pool.match_resources(descriptors)
    render :json => matched
  end
end
