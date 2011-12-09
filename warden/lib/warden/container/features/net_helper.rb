require "warden/container/spawn"

module Warden

  module Container

    module Features

      module NetHelper

        include Spawn

        protected

        def iptables_rule(chain, *args)
          options =
            if args[-1].respond_to?(:to_hash)
              args.pop.to_hash
            else
              {}
            end

          rule = args.join(" ")
          regexp = Regexp.new("\\s" + Regexp.escape(rule).gsub(" ", "\\s+") + "(\\s|$)")
          table = %{-t "#{options[:table]}"} if options.has_key?(:table)
          rules = sh("iptables #{table} -S #{chain}").
            split(/\n/).
            select { |e| e =~ regexp }
          rule_enabled = !rules.empty?

          unless rule_enabled
            sh "iptables #{table} -A #{chain} #{rule}"
          end
        end

        def ip_route
          sh("ip route get 1.1.1.1").chomp
        end

        def external_interface
          iface = ip_route[/ dev (\w+)/i, 1]
          if iface.nil?
            raise WardenError.new("unable to detect external interface")
          end

          iface
        end

        def external_ip
          ip = ip_route[/ src ([\d\.]+)/i, 1]
          if ip.nil?
            raise WardenError.new("unable to detect external ip")
          end

          ip
        end
      end
    end
  end
end
