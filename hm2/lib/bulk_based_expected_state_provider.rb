require 'rest-client'

module HealthManager2
  #this implementation will use the REST(ish) BulkAPI to
  #interrogate the CloudController on the expected state of the apps
  #the API should allow for non-blocking operation
  class BulkBasedExpectedStateProvider < ExpectedStateProvider

    attr_reader :current_batch

    def rewind
      @bulk_token = {}
      @current_batch = []
    end

    def next_droplet
      retrieve_batch if current_batch.empty?
      current_batch.shift
    end

    def retrieve_batch

    end

    private

    def host
      @config['host'] || 'localhost'
    end

    def app_url
      "http://#{host}/bulk/apps"
    end

    def ensure_authenticated
      #just yield if already authenticated.  Authenticate and then yield otherwise
      if @user && @password
        yield
      else
        NATS.request('cloudcontroller.bulk.credentials') do |response|
          auth =  parse_json(response)
          @user = auth[:user] || auth['user']
          @password = auth[:password] || auth['password']
          yield
        end
      end
    end
  end
end
