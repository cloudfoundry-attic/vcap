class BulkController < ApplicationController

  #http_basic_authenticate_with :name => 'bulk_api', :password => AppConfig[:bulk_api_password]
  #TODO: rewrite to only allow inter-component communication
  #use simple http auth.
  #setup credentials at startup
  #send them as a response to NATS request cloudcontroller.bulk.credentials

  DEFAULT_BATCH_SIZE = 200

  def apps
    retrieve_results(App)
    update_token

    render :json => { :results => hash_by_id(results), :bulk_token => bulk_token }
  end

  private

  def retrieve_results(model)
    @results ||= model.where(where_clause).limit(batch_size).to_a
  end

  def hash_by_id arr
    arr.inject({}) { |hash, elem| hash[elem.id] = elem; hash }
  end


  def results
    @results
  end

  def update_token
    @bulk_token = results.empty? ? {} : {:id => results.last.id}
  end

  def where_clause
    @where_clause ||= bulk_token.to_a.map { |k,v| "#{k} > #{v}" }.join(" AND ")
  end

  def batch_size
    @batch_size||=params['batch_size'] ? json_param('batch_size').to_i : DEFAULT_BATCH_SIZE
  end

  def bulk_token
    @bulk_token||=params['bulk_token'] ? params['bulk_token'] : {}
  end
end
