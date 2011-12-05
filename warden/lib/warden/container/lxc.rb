require "warden/errors"
require "warden/container/base"
require "warden/container/script_handler"
require "warden/container/remote_script_handler"
require "warden/container/uid_pool"

module Warden

  module Container

    class LXC < Base

      class << self
        # This needs to be set before using any containers. The users contained
        # in this pool are used to enforce disk usage limits via filesystem
        # quotas.
        #
        # NB: This imposes a hard limit on the number of containers that may exist
        #     at any one time (similar to network_pool in base.rb). Size it appropriately.
        attr_accessor :uid_pool

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

        def setup(config={})
          unless Process.uid == 0
            raise WardenError.new("lxc requires root privileges")
          end

          cgroup_path = "/dev/cgroup"
          cgroup_mounts = IO.readlines("/proc/mounts").
            map(&:split).
            select { |e| e[1] == cgroup_path }. # mount point
            select { |e| e[2] == "cgroup" }     # fs type

          if cgroup_mounts.empty?
            sh "mkdir -p #{cgroup_path}"
            sh "mount -t cgroup none #{cgroup_path}"
          end

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

          # 1k available ports should be "good enough"
          if PortPool.instance.available < 1000
            message = "insufficient non-ephemeral ports available"
            message += " (expected >= 1000, got: #{PortPool.instance.available})"
            raise WardenError.new(message)
          end

          # Acquire users for quota limits
          if config[:uidpool]
            up_config = config[:uidpool]
            self.uid_pool = Warden::Container::UidPool.acquire(up_config[:name], up_config[:count])
          end
        end
      end

      attr_reader :uid

      def initialize
        super

        on(:before_create) {
          # Inbound port forwarding rules MUST be deleted before the container is started
          clear_inbound_port_forwarding_rules
        }

        on(:after_destroy) {
          # Inbound port forwarding rules SHOULD be deleted after the container is stopped
          clear_inbound_port_forwarding_rules

          # Release uid used for this container (if any). Only do so if the container
          # was successfully destroyed.
          self.class.uid_pool.release(self.uid) if self.uid
        }

        # XXX - Possible to leak a uid here if connection registration fails. Need to refactor
        #       Base to make atomic resource allocation easier.
        @uid = self.class.uid_pool.acquire if self.class.uid_pool
      end

      def container_root_path
        File.join(container_path, "union")
      end

      def env
        env = {
          "id" => handle,
          "network_gateway_ip" => gateway_ip.to_human,
          "network_container_ip" => container_ip.to_human,
          "network_netmask" => self.class.network_pool.netmask.to_human,
        }
        env['vcap_uid'] = self.uid if self.uid
        env
      end

      def env_command
        "env #{env.map { |k, v| "#{k}=#{v}" }.join(" ")}"
      end

      def do_create
        # Create container
        sh "#{env_command} #{root_path}/create.sh #{handle}"
        debug "container created"

        # Start container
        sh "#{container_path}/start.sh"
        debug "container started"
      end

      def do_destroy
        # Stop container
        sh "#{container_path}/stop.sh"
        debug "container stopped"

        # Destroy container
        sh "rm -rf #{container_path}"
        debug "container destroyed"
      end

      def create_job(script)
        socket_path = File.join(container_root_path, "/tmp/runner.sock")
        unless File.exist?(socket_path)
          error "socket does not exist: #{socket_path}"
        end

        job = Job.new(self)
        handler = ::EM.connect_unix_domain(socket_path, RemoteScriptHandler)

        # Send path to job artifact directory on the first line
        handler.send_data(job.path + "\n")

        # The remainder of stdin will be consumed by a subshell
        handler.send_data(script + "\n")

        # Make bash exit without losing the exit status. This can otherwise
        # be done by shutting down the write side of the socket, causing EOF
        # on stdin for the remote. However, EM doesn't do shutdown...
        handler.send_data "exit $?\n"

        handler.callback { job.finish }

        job
      end

      def _net_inbound_port
        port = PortPool.acquire

        rule = [
          "--protocol tcp",
          "--destination-port #{port}",
          "--jump DNAT",
          "--to-destination #{container_ip.to_human}:#{port}" ]
        sh "iptables -t nat -A warden #{rule.join(" ")}"

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
          %{iptables -t nat -S warden},
          %{grep " #{Regexp.escape(container_ip.to_human)}:"},
          %{sed s/-A/-D/},
          %{xargs -L 1 -r iptables -t nat} ]
        sh commands.join(" | ")
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
