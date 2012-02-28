require "warden/errors"
require "warden/container/spawn"

module Warden

  module Container

    module Features

      module Net

        include Spawn

        def self.included(base)
          base.extend(ClassMethods)
        end

        def initialize(*args)
          super(*args)

          on(:after_create) {
            sh "#{container_path}/net.sh setup"
          }

          on(:before_destroy) {
            sh "#{container_path}/net.sh teardown"
          }
        end

        def do_net_in
          port = PortPool.acquire

          sh *[ %{env},
                %{PORT=%s} % port,
                %{%s/net.sh} % container_path,
                %{in} ]

          # Port may be re-used after this container has been destroyed
          on(:after_destroy) {
            PortPool.release(port)
          }

          # Return mapped port to the caller
          port

        rescue WardenError
          PortPool.release(port)
          raise
        end

        def do_net_out(spec)
          network, port = spec.split(":")

          sh *[ %{env},
                %{NETWORK=%s} % network,
                %{PORT=%s} % port,
                %{%s/net.sh} % container_path,
                %{out} ]

          "ok"
        end

        module ClassMethods

          include Spawn

          # Network blacklist
          attr_accessor :deny_networks

          # Network whitelist
          attr_accessor :allow_networks

          def setup(config = {})
            super(config)

            allow_networks = []
            if config[:network]
              allow_networks = [config[:network][:allow_networks]].flatten.compact
            end

            deny_networks = []
            if config[:network]
              deny_networks = [config[:network][:deny_networks]].flatten.compact
            end

            sh *[ %{env},
                  %{ALLOW_NETWORKS=%s} % allow_networks.join(" "),
                  %{DENY_NETWORKS=%s} % deny_networks.join(" "),
                  %{%s/net.sh} % root_path,
                  %{setup} ]

            # 1k available ports should be "good enough"
            if PortPool.instance.available < 1000
              message = "insufficient non-ephemeral ports available"
              message += " (expected >= 1000, got: #{PortPool.instance.available})"
              raise WardenError.new(message)
            end
          end
        end

        class PortPool

          class NoPortAvailable < WardenError

            def message
              super || "no port available"
            end
          end

          def self.acquire
            instance.acquire
          end

          def self.release(port)
            instance.release(port)
          end

          def self.instance
            @instance ||= new
          end

          include Spawn

          def initialize
            out = sh "cat /proc/sys/net/ipv4/ip_local_port_range | cut -f2"
            start = out.to_i + 1
            stop = 65_000

            # The port range spanned by [start, stop) does not overlap with the
            # ephemeral port range and will therefore not conflict with ports
            # used by locally originated connection. It is safe to map these
            # ports to containers.
            @pool = Range.new(start, stop, false).to_a
          end

          def available
            @pool.size
          end

          def acquire
            port = @pool.shift
            raise NoPortAvailable if port.nil?

            port
          end

          def release(port)
            @pool.push port
          end
        end
      end
    end
  end
end
