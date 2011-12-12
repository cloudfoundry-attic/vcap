require "warden/errors"
require "warden/container/spawn"
require "warden/container/features/net_helper"

module Warden

  module Container

    module Features

      module NetIn

        include Spawn

        def self.included(base)
          base.extend(ClassMethods)
        end

        def initialize(*args)
          super(*args)

          on(:before_create) {
            # Inbound port forwarding rules MUST be deleted before the container is started
            clear_inbound_port_forwarding_rules
          }

          on(:after_destroy) {
            # Inbound port forwarding rules SHOULD be deleted after the container is stopped
            clear_inbound_port_forwarding_rules
          }
        end

        def do_net_in
          port = PortPool.acquire

          rule = [
            "--protocol tcp",
            "--destination-port #{port}",
            "--jump DNAT",
            "--to-destination #{container_ip.to_human}:#{port}" ]
            sh "iptables -t nat -A warden-prerouting #{rule.join(" ")}"

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

        protected

        def clear_inbound_port_forwarding_rules
          commands = [
            %{iptables -t nat -S warden-prerouting},
            %{grep " #{Regexp.escape(container_ip.to_human)}:"},
            %{sed s/-A/-D/},
            %{xargs -L 1 -r iptables -t nat} ]
          sh commands.join(" | ")
        end

        module ClassMethods

          include NetHelper
          include Spawn

          def setup(config = {})
            super(config)

            # Prepare chain for DNAT
            sh "iptables -t nat -N warden-prerouting", :raise => false
            sh "iptables -t nat -F warden-prerouting"
            iptables_rule "-t nat -A PREROUTING",
              %{--in-interface #{external_interface}},
              %{--jump warden-prerouting}

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
