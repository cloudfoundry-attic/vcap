require "optparse"
require "warden/container/spawn"

module Warden

  module Container

    module Features

      module NetHelper

        include Spawn

        IPT_COMMAND_NEW     = /^\s*-(?:-new|N)\s+([^\s]+)(?:\s|$)/
        IPT_COMMAND_APPEND  = /^\s*-(?:-append|A)\s+([^\s]+)(?:\s|$)/
        IPT_COMMAND_DELETE  = /^\s*-(?:-delete|D)\s+([^\s]+)(?:\s|$)/
        IPT_COMMAND_POLICY  = /^\s*-(?:-policy|P)\s+([^\s]+)\s+([^\s]+)(?:\s|$)/

        IPT_OPT_TABLE       = /^\s*-(?:-table|t)\s+([^\s]+)(?:\s|$)/
        IPT_OPT_PROTO       = /^\s*(\!\s+)?-(?:-proto|p)\s+([^\s]+)(?:\s|$)/
        IPT_OPT_SOURCE      = /^\s*(\!\s+)?-(?:-source|s)\s+([^\s]+)(?:\s|$)/
        IPT_OPT_DESTINATION = /^\s*(\!\s+)?-(?:-destination|d)\s+([^\s]+)(?:\s|$)/
        IPT_OPT_IN_IFACE    = /^\s*(\!\s+)?-(?:-in-interface|i)\s+([^\s]+)(?:\s|$)/
        IPT_OPT_OUT_IFACE   = /^\s*(\!\s+)?-(?:-out-interface|o)\s+([^\s]+)(?:\s|$)/
        IPT_OPT_JUMP        = /^\s*-(?:-jump|j)\s+([^\s]+)(?:\s|$)/
        IPT_OPT_GOTO        = /^\s*-(?:-goto|g)\s+([^\s]+)(?:\s|$)/
        IPT_OPT_NUMERIC     = /^\s*-(?:-numeric|n)(?:\s|$)/

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
            when IPT_COMMAND_NEW
              rule["command"] = [:new, $1]
              rule["chain"] = $1
            when IPT_COMMAND_APPEND
              rule["command"] = [:append, $1]
              rule["chain"] = $1
            when IPT_COMMAND_DELETE
              rule["command"] = [:delete, $1]
              rule["chain"] = $1
            when IPT_COMMAND_POLICY
              rule["command"] = [:policy, $1, $2]
              rule["chain"] = $1

            # Options
            when IPT_OPT_TABLE
              rule["table"] = $1
            when IPT_OPT_PROTO
              rule["protocol"] = [$1.nil?, $2]
            when IPT_OPT_SOURCE
              rule["source"] = [$1.nil?, $2]
            when IPT_OPT_DESTINATION
              rule["destination"] = [$1.nil?, $2]
            when IPT_OPT_IN_IFACE
              rule["in-interface"] = [$1.nil?, $2]
            when IPT_OPT_OUT_IFACE
              rule["out-interface"] = [$1.nil?, $2]
            when IPT_OPT_JUMP
              rule["jump"] = $1
            when IPT_OPT_GOTO
              rule["goto"] = $1
            when IPT_OPT_NUMERIC
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
