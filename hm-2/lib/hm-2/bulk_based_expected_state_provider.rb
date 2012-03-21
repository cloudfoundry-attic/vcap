require 'em-http'

module HM2
  #this implementation will use the REST(ish) BulkAPI to
  #interrogate the CloudController on the expected state of the apps
  #the API should allow for non-blocking operation
  class BulkBasedExpectedStateProvider < ExpectedStateProvider

    def each_droplet(&block)
      process_next_batch({},&block)
    end

    def set_expected_state(known, expected)

      @logger.debug { "bulk: #set_expected_state: known: #{known.inspect} expected: #{expected.inspect}" }

      known.num_instances = expected['instances']
      known.state = expected['state']
      known.live_version = "#{expected['staged_package_hash']}-#{expected['run_count']}"
      known.framework = expected['framework']
      known.runtime = expected['runtime']
      known.last_updated = parse_utc(expected['updated_at'])
    end

    private
    def process_next_batch(bulk_token,&block)
      with_credentials do |user, password|
        options = {
          :head => { 'authorization' => [user,password] },
          :query => {
            'batch_size' => batch_size,
            'bulk_token' => bulk_token.to_json
          },
        }
        http = EM::HttpRequest.new(app_url).get(options)
        http.callback {

          if http.response_header.status != 200
            @logger.error("bulk request problem. Response: #{http.response_header} #{http.response}")
            next
          end

          response = parse_json(http.response)
          bulk_token = response['bulk_token']
          batch = response['results']
          next if batch.nil? || batch.empty?

          @logger.debug {"bulk api batch of size #{batch.size} received"}

          batch.each do |app_id, droplet|
            block.call(app_id, droplet)
          end
          process_next_batch(bulk_token, &block)
        }
        http.errback {
          @logger.error("problem talking to bulk API at #{app_url}")
          @user = @password = nil #ensure re-acquisition of credentials
        }
      end
    end

    def host
      (@config['bulk'] && @config['bulk']['host']) || "api.vcap.me"
    end

    def batch_size
      (@config['bulk'] && @config['bulk']['batch_size']) || "50"
    end

    def app_url
      url = "#{host}/bulk/apps"
      url = "http://"+url unless url.start_with?("http://")
      url
    end

    def with_credentials
      if @user && @password
        yield @user, @password
      else
        @logger.info("requesting bulk API credentials over NATS...")
        sid = NATS.request('cloudcontroller.bulk.credentials') do |response|
          @logger.info("...bulk API credentials received: #{response}")
          auth =  parse_json(response)
          @user = auth[:user] || auth['user']
          @password = auth[:password] || auth['password']
          yield @user, @password
        end

        NATS.timeout(sid,
                     get_param_from_config_or_constant(:nats_request_timeout,@config)) do
          @logger.error("NATS timeout getting bulk api credentials. Jussayin'... Request ignored.")
        end
      end
    end
  end
end
