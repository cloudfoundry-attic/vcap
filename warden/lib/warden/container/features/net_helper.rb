require "optparse"
require "warden/container/spawn"

module Warden

  module Container

    module Features

      module NetHelper

        include Spawn

        # This method makes an attempt at parsing the semantics of typical
        # iptables commands. This is done to be able to compare existing rules
        # with new rules, to see if they should be added or not. It is nowhere
        # near complete but should provide enough functionality here.

        def parse_iptables_command(command)
          buffer = command.dup
          rule = {}

          # Remove command name if present
          if buffer =~ /^\s*([^\s]*iptables)/
            buffer = buffer[$&.length, buffer.length]
          end

          while !buffer.chomp.empty?
            case buffer

            # Commands
            when /^\s*-(?:-new|N)\s+([^\s]+)(?:\s|$)/
              rule["command"] = [:new, $1]
              rule["chain"] = $1
            when /^\s*-(?:-append|A)\s+([^\s]+)(?:\s|$)/
              rule["command"] = [:append, $1]
              rule["chain"] = $1
            when /^\s*-(?:-delete|D)\s+([^\s]+)(?:\s|$)/
              rule["command"] = [:delete, $1]
              rule["chain"] = $1
            when /^\s*-(?:-policy|P)\s+([^\s]+)\s+([^\s]+)(?:\s|$)/
              rule["command"] = [:policy, $1, $2]
              rule["chain"] = $1

            # Options
            when /^\s*-(?:-table|t)\s+([^\s]+)(?:\s|$)/
              rule["table"] = $1
            when /^\s*(\!\s+)?-(?:-proto|p)\s+([^\s]+)(?:\s|$)/
              rule["protocol"] = [$1.nil?, $2]
            when /^\s*(\!\s+)?-(?:-source|s)\s+([^\s]+)(?:\s|$)/
              rule["source"] = [$1.nil?, $2]
            when /^\s*(\!\s+)?-(?:-destination|d)\s+([^\s]+)(?:\s|$)/
              rule["destination"] = [$1.nil?, $2]
            when /^\s*(\!\s+)?-(?:-in-interface|i)\s+([^\s]+)(?:\s|$)/
              rule["in-interface"] = [$1.nil?, $2]
            when /^\s*(\!\s+)?-(?:-out-interface|o)\s+([^\s]+)(?:\s|$)/
              rule["out-interface"] = [$1.nil?, $2]
            when /^\s*-(?:-jump|j)\s+([^\s]+)(?:\s|$)/
              rule["jump"] = $1
            when /^\s*-(?:-goto|g)\s+([^\s]+)(?:\s|$)/
              rule["goto"] = $1
            when /^\s*-(?:-numeric|n)(?:\s|$)/
              # doesn't affect rule, ignore
            else
              raise "cannot parse: #{buffer.inspect}"
            end

            # Trim buffer
            buffer = buffer[$&.length, buffer.length]
          end

          rule
        end

        protected

        def iptables_existing_rules(chain, table = nil)
          command = %{iptables -S "#{chain}"}
          command << %{ -t "#{table}"} if table

          rules = sh(command).
            split(/\n/).
            map { |command| parse_iptables_command(command) }

          Set.new(rules)
        end

        def iptables_rule(*args)
          command = ["iptables", args].join(" ")
          options = parse_iptables_command(command)
          table = options.delete("table")

          # Check whether or not this rule should be added
          rules = iptables_existing_rules(options["chain"], table)
          unless rules.member?(options)
            sh(command)
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
