# Copyright (c) 2009-2011 VMware, Inc.
require "eventmachine"
require 'thin'
require "yajl"
require "nats/client"
require "base64"
require 'set'

module VCAP

  RACK_JSON_HDR = { 'Content-Type' => 'application/json' }
  RACK_TEXT_HDR = { 'Content-Type' => 'text/plaintext' }

  class Varz
    def initialize(logger)
      @logger = logger
    end

    def call(env)
      @logger.debug "varz access"
      varz = Yajl::Encoder.encode(Component.updated_varz, :pretty => true, :terminator => "\n")
      [200, { 'Content-Type' => 'application/json' }, varz]
    rescue => e
      @logger.error "varz error #{e.inspect} #{e.backtrace.join("\n")}"
      raise e
    end
  end

  class Healthz
    def initialize(logger)
      @logger = logger
    end

    def call(env)
      @logger.debug "healthz access"
      healthz = Component.updated_healthz
      [200, { 'Content-Type' => 'application/json' }, healthz]
    rescue => e
      @logger.error "healthz error #{e.inspect} #{e.backtrace.join("\n")}"
      raise e
    end
  end

  # Common component setup for discovery and monitoring
  class Component

    # We will suppress these from normal varz reporting by default.
    CONFIG_SUPPRESS = Set.new([:mbus, :service_mbus, :keys, :database_environment, :mysql, :password])

    class << self

      attr_reader   :varz
      attr_accessor :healthz

      def updated_varz
        @last_varz_update ||= 0
        if Time.now.to_f - @last_varz_update >= 1
          # Snapshot uptime
          @varz[:uptime] = VCAP.uptime_string(Time.now - @varz[:start])

          # Grab current cpu and memory usage.
          rss, pcpu = `ps -o rss=,pcpu= -p #{Process.pid}`.split
          @varz[:mem] = rss.to_i
          @varz[:cpu] = pcpu.to_f

          @last_varz_update = Time.now.to_f
        end
        varz
      end

      def updated_healthz
        @last_healthz_update ||= 0
        if Time.now.to_f - @last_healthz_update >= 1
          # ...
          @last_healthz_update = Time.now.to_f
        end

        healthz
      end

      def start_http_server(host, port, auth, logger)
        http_server = Thin::Server.new(host, port, :signals => false) do
          Thin::Logging.silent = true
          use Rack::Auth::Basic do |username, password|
            [username, password] == auth
          end
          map '/healthz' do
            run Healthz.new(logger)
          end
          map '/varz' do
            run Varz.new(logger)
          end
        end
        http_server.start!
      end

      def uuid
        @discover[:uuid]
      end

      def register(opts)
        uuid = VCAP.secure_uuid
        type = opts[:type]
        index = opts[:index]
        uuid = "#{index}-#{uuid}" if index
        host = opts[:host] || VCAP.local_ip
        port = opts[:port] || VCAP.grab_ephemeral_port
        nats = opts[:nats] || NATS
        auth = [opts[:user] || VCAP.secure_uuid, opts[:password] || VCAP.secure_uuid]
        logger = opts[:logger] || Logger.new(nil)

        # Discover message limited
        @discover = {
          :type => type,
          :index => index,
          :uuid => uuid,
          :host => "#{host}:#{port}",
          :credentials => auth,
          :start => Time.now
        }

        # Varz is customizable
        @varz = @discover.dup
        @varz[:num_cores] = VCAP.num_cores
        @varz[:config] = sanitize_config(opts[:config]) if opts[:config]

        @healthz = "ok\n".freeze

        # Next steps require EM
        raise "EventMachine reactor needs to be running" if !EventMachine.reactor_running?

        # Startup the http endpoint for /varz and /healthz
        start_http_server(host, port, auth, logger)

        # Listen for discovery requests
        nats.subscribe('vcap.component.discover') do |msg, reply|
          update_discover_uptime
          nats.publish(reply, @discover.to_json)
        end

        # Also announce ourselves on startup..
        nats.publish('vcap.component.announce', @discover.to_json)
      end

      def update_discover_uptime
        @discover[:uptime] = VCAP.uptime_string(Time.now - @discover[:start])
      end

      def clear_level(h)
        h.each do |k, v|
          if CONFIG_SUPPRESS.include?(k.to_sym)
            h.delete(k)
          else
            clear_level(h[k]) if v.instance_of? Hash
          end
        end
      end

      def sanitize_config(config)
        # Can't Marshal/Deep Copy logger instances that services use
        if config[:logger]
          config = config.dup
          config.delete(:logger)
        end
        # Deep copy
        config = Marshal.load(Marshal.dump(config))
        clear_level(config)
        config
      end
    end
  end
end
