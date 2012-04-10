class BulkController < ApplicationController

  skip_before_filter :fetch_user_from_token
  before_filter :authenticate_bulk_api

  #the password is randomly generated at startup and is
  #discoverable through NATS.request('cloudcontroller.bulk.credentials')

  DEFAULT_BATCH_SIZE = 200


  def users
    render_results_and_token_for_model(User)
  end

  def apps
    render_results_and_token_for_model(App)
  end

  private

  def authenticate_bulk_api
    authenticate_or_request_with_http_basic do |user, pass|
      if user==AppConfig[:bulk_api][:auth][:user] &&
          pass==AppConfig[:bulk_api][:auth][:password]
        true
      else
        CloudController.logger.error("Bulk api auth failed (user=#{user}, pass=#{pass} from #{request.remote_ip}", :tags => [:auth_failure, :bulk_api])
        false
      end
    end

  end

  def render_results_and_token_for_model(model)
    results = retrieve_results(model)
    update_token(results)
    render :json => { :results => hash_by_id(results), :bulk_token => bulk_token }
  end

  def retrieve_results(model)
    model.where(where_clause).limit(batch_size).to_a
  end

  def hash_by_id arr
    arr.inject({}) { |hash, elem| hash[elem.id] = elem; hash }
  end

  def update_token(results)
    @bulk_token = results.empty? ? {} : {:id => results.last.id}
  end

  def where_clause
    @where_clause ||= bulk_token.to_a.map { |k,v| "#{sanitize_atom(k)} > #{sanitize_atom(v)}" }.join(" AND ")
  end

  def sanitize_atom(atom)
    unless atom =~ /^\w+$/
      raise CloudError.new(CloudError::BAD_REQUEST, "bad atom #{atom} in bulk_api token")
    end
    atom
  end


  def batch_size
    @batch_size||=params['batch_size'] ? json_param('batch_size').to_i : DEFAULT_BATCH_SIZE
  end

  def bulk_token
    @bulk_token||=params['bulk_token'] ? params['bulk_token'] : {}
  end
end
