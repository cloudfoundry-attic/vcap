require "warden/errors"
require "warden/container/spawn"

module Warden

  module Container

    module Features

      module NetOut

        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods

          include Spawn

          def iptables_rule(chain, rule)
            regexp = Regexp.new("\\s" + Regexp.escape(rule).gsub(" ", "\\s+") + "(\\s|$)")
            rules = sh("iptables -t nat -S #{chain}").
              split(/\n/).
              select { |e| e =~ regexp }
            rule_enabled = !rules.empty?

            unless rule_enabled
              sh "iptables -t nat -A #{chain} #{rule}"
            end
          end

          def setup(config = {})
            super(config)

            ip_route = sh("ip route get 1.1.1.1").chomp

            external_interface = ip_route[/ dev (\w+)/i, 1]
            if external_interface.nil?
              raise WardenError.new("unable to detect external interface")
            end

            external_ip = ip_route[/ src ([\d\.]+)/i, 1]
            if external_ip.nil?
              raise WardenError.new("unable to detect external ip")
            end

            sh "echo 1 > /proc/sys/net/ipv4/ip_forward"
            sh "iptables -t nat -N warden", :raise => false
            sh "iptables -t nat -F warden"

            iptables_rule("POSTROUTING", "-o #{external_interface} -j MASQUERADE")
            iptables_rule("PREROUTING", "-i #{external_interface} -j warden")
          end
        end
      end
    end
  end
end
