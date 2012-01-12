require "warden/errors"
require "warden/container/spawn"
require "warden/container/features/net_helper"

module Warden

  module Container

    module Features

      module NetOut

        include Spawn

        def self.included(base)
          base.extend(ClassMethods)
        end

        def initialize(*args)
          super(*args)

          on(:before_create) {
            # Outbound whitelisting rules MUST be deleted before the container is started
            clear_outbound_whitelisting_rules
          }

          on(:after_destroy) {
            # Outbound whitelisting rules SHOULD be deleted after the container is stopped
            clear_outbound_whitelisting_rules
          }
        end

        def network_iface_host
          @network_iface_host ||= "veth-%s-0" % handle
        end

        def network_iface_container
          @network_iface_container ||= "veth-%s-1" % handle
        end

        def do_net_out(spec)
          address, port = spec.split(":")

          rule = []
          rule << %{--in-interface #{network_iface_host}}
          rule << %{--destination "#{address}"}
          rule << %{--destination-port "#{port}"} if port
          rule << %{--jump RETURN}

          sh "iptables -I warden-forward #{rule.join(" ")}"

          "ok"
        end

        protected

        def clear_outbound_whitelisting_rules
          commands = [
            %{iptables -S warden-forward},
            %{grep " -i veth-#{handle}"},
            %{sed s/-A/-D/},
            %{xargs -L 1 -r iptables} ]
          sh commands.join(" | ")
        end

        module ClassMethods

          include NetHelper
          include Spawn

          # Network blacklist
          attr_accessor :deny_networks

          # Network whitelist
          attr_accessor :allow_networks

          def setup(config = {})
            super(config)

            deny_networks = []
            if config[:network]
              deny_networks = [config[:network][:deny_networks]].flatten.compact
            end

            allow_networks = []
            if config[:network]
              allow_networks = [config[:network][:allow_networks]].flatten.compact
            end

            sh "echo 1 > /proc/sys/net/ipv4/ip_forward"

            # Containers may not communicate with local interfaces
            sh "iptables -N warden-input", :raise => false
            sh "iptables -F warden-input"
            iptables_rule "-A INPUT",
              %{--in-interface veth+},
              %{--jump warden-input}
            iptables_rule "-A warden-input",
              %{--jump DROP}

            # Filter outgoing traffic
            sh "iptables -N warden-forward", :raise => false
            sh "iptables -F warden-forward"
            iptables_rule "-A FORWARD",
              %{--in-interface veth+},
              %{--jump warden-forward}

            # Whitelist
            allow_networks.each do |network|
              iptables_rule "-A warden-forward",
                %{--destination #{network}},
                %{--jump RETURN}
            end

            # Blacklist
            deny_networks.each do |network|
              iptables_rule "-A warden-forward",
                %{--destination #{network}},
                %{--jump DROP}
            end

            # Masquerade outgoing traffic
            iptables_rule "-t nat -A POSTROUTING",
              %{--out-interface #{external_interface}},
              %{--jump MASQUERADE}
          end
        end
      end
    end
  end
end
