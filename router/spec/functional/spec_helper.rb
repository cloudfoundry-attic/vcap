# Copyright (c) 2009-2011 VMware, Inc.
require File.dirname(__FILE__) + '/../lib/spec_helper'

module Functional

  class TestApp
    class UsageError < StandardError; end

    attr_reader :uris, :droplet

    def initialize(*uris)
      @uris = uris
    end

    def bind_droplet(droplet)
      @droplet = droplet
    end

    def unbind_droplet
      @droplet = nil
    end

    def port
      @droplet.port if @droplet
    end

    def verify_registered
      for uri in @uris
        status, body = query_uls(uri)
        status.should == 200
        Yajl::Parser.parse(body)["backend_addr"].should == droplet.host_port
      end
    end

    def verify_unregistered
      for uri in @uris
        status, body = query_uls(uri)
        status.should == 404
      end
    end

    private

    def query_uls(uri)
      parser, body = nil, nil
      UNIXSocket.open(RouterServer.sock) do |socket|
        socket.send(simple_uls_request(uri), 0)
        socket.close_write
        buf = socket.read
        parser, body = parse_http_msg(buf)
        socket.close
      end
      return parser.status_code, body
    end

    def simple_uls_request(host)
      body = { :host => host }.to_json
      "GET / HTTP/1.0\r\nConnection: Keep-alive\r\nHost: localhost\r\nContent-Length: #{body.length}\r\nContent-Type: application/json\r\nX-Vcap-Service-Token: changemysqltoken\r\nUser-Agent: EventMachine HttpClient\r\n\r\n#{body}"
    end

    def parse_http_msg(buf)
      parser = Http::Parser.new
      body = ''

      parser.on_body = proc do |chunk|
        body << chunk
      end

      parser.on_message_complete = proc do
        :stop
      end

      parser << buf

      return parser, body
    end

  end

  class Droplet
    attr_reader :host, :port

    def initialize(host)
      @host = host
      @port = Random.rand(100_000)
    end

    def host_port
      "#{host}:#{port}"
    end
  end

  class DummyDea

    attr_reader :nats_uri, :dea_id

    def initialize(nats_uri, dea_id, host='127.0.0.1')
      @nats_uri = nats_uri
      @dea_id = dea_id
      @host = host
    end

    def reg_hash_for_app(app, tags = {})
      { :dea  => @dea_id,
        :host => @host,
        :port => app.port,
        :uris => app.uris,
        :tags => tags
      }
    end

    def register_app(app, tags = {})
      droplet = Droplet.new(@host)
      app.bind_droplet(droplet)
      NATS.start(:uri => @nats_uri) do
        NATS.publish('router.register', reg_hash_for_app(app, tags).to_json) { NATS.stop }
      end
    end

    def unregister_app(app)
      NATS.start(:uri => @nats_uri) do
        NATS.publish('router.unregister', reg_hash_for_app(app).to_json) { NATS.stop }
      end
    end
  end

end
