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
        droplet.host_port.should == query_uls(uri)
      end
    end

    def verify_unregistered
      for uri in @uris
        query_should_fail(uri)
      end
    end

    private

    def query_should_fail(uri)
      req = simple_uls_request(uri)
      res = nil
      UNIXSocket.open(RouterServer.sock) do |socket|
        socket.send(req, 0)
        buf = socket.read
        buf.should == ERROR_404_RESPONSE
      end
    end

    def query_uls(uri)
      req = simple_uls_request(uri)
      res = nil
      UNIXSocket.open(RouterServer.sock) do |socket|
        socket.send(req, 0)
        buf = socket.read
        body = buf.split("\r\n\r\n")[1]
        res = Yajl::Parser.parse(body)["backend_addr"]
        socket.close
      end
      res
    end

    def simple_uls_request(host)
      body = { :host => host }.to_json
      "GET / HTTP/1.0\r\nConnection: Keep-alive\r\nHost: localhost\r\nContent-Length: #{body.length}\r\nContent-Type: application/json\r\nX-Vcap-Service-Token: changemysqltoken\r\nUser-Agent: EventMachine HttpClient\r\n\r\n#{body}"
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
