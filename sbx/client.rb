require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'json'

SERVER_IP = '127.0.0.1'
PORT = 3000
BASE_REQUEST = "http://#{SERVER_IP}:#{PORT}/".freeze

class Client
  class << self

    def app_list
      EM::HttpRequest.new(BASE_REQUEST).get.callback { |http|
        puts http.response
      }
    end

    def create_sandbox(config=nil, &blk)
      # POST / :body => config

      body = config == nil ? "" : config.to_json
      options = {:inactivity_timeout => 120}
      request = EM::HttpRequest.new(BASE_REQUEST, options).post(:body => body)
      request.callback { |http|
        if blk
            blk.call if blk.arity == 0
            blk.call(http.response) if blk.arity == 1
        end
      }
      request.errback { |http|
        puts "Error: #{http.error}"
      }
    end

    def delete_sandbox(handle, &blk)
      options = {:inactivity_timeout => 120}
      request = EM::HttpRequest.new(BASE_REQUEST + handle, options).delete
      request.callback { |http|
        if blk
          blk.call if blk.arity == 0
          blk.call(http.response) if blk.arity == 1
        end
      }
      request.errback { |http|
        puts "Error: #{http.error}"
      }
    end

  end
end
