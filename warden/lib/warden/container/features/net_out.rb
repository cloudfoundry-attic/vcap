require "warden/errors"
require "warden/container/spawn"
require "warden/container/features/net_helper"

module Warden

  module Container

    module Features

      module NetOut

        def self.included(base)
          base.extend(ClassMethods)
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
              deny_networks = [config[:network][:allow_networks]].flatten.compact
            end

            sh "echo 1 > /proc/sys/net/ipv4/ip_forward"

            # Containers may not communicate with local interfaces
            sh "iptables -N warden-input", :raise => false
            sh "iptables -F warden-input"
            iptables_rule "INPUT",
              %{--in-interface veth+},
              %{--jump warden-input}
            iptables_rule "warden-input",
              %{--jump DROP}

            # Filter outgoing traffic
            sh "iptables -N warden-forward", :raise => false
            sh "iptables -F warden-forward"
            iptables_rule "FORWARD",
              %{--in-interface veth+},
              %{--jump warden-forward}

            # Whitelist
            allow_networks.each do |network|
              iptables_rule "FORWARD",
                %{--destination #{network}},
                %{--jump RETURN}
            end

            # Blacklist
            deny_networks.each do |network|
              iptables_rule "FORWARD",
                %{--destination #{network}},
                %{--jump DROP}
            end

            # Masquerade outgoing traffic
            iptables_rule "POSTROUTING",
              %{--out-interface #{external_interface}},
              %{--jump MASQUERADE},
              :table => :nat
          end
        end
      end
    end
  end
end
