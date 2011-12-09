require 'vcap/quota'

require "warden/errors"
require "warden/container/base"
require "warden/container/script_handler"
require "warden/container/remote_script_handler"
require "warden/container/uid_pool"

module Warden

  module Container

    class LXC < Base

      module Quota

        include Spawn

        def self.included(base)
          base.extend(ClassMethods)
        end

        def initialize(*args)
          super

          if self.class.quota_monitor
            # Reset quota for user
            set_quota(0)

            self.class.quota_monitor.register(self) do
              self.warn "Disk quota (#{self.disk_quota}) exceeded, destroying"
              self.class.quota_monitor.unregister(self)
              # TODO - Change this to stop() once available
              self.destroy
            end
          end

          on(:after_destroy) {
            # Release uid used for this container (if any). Only do so if the container
            # was successfully destroyed.
            if self.class.quota_monitor
              self.class.quota_monitor.unregister(self)
              set_quota(0)
            end
          }
        end

        def uid
          @resources[:uid]
        end

        def disk_quota
          @disk_quota ||= 0
        end

        def disk_quota=(v)
          @disk_quota = v
        end

        def get_limit_disk
          unless self.uid && self.class.quota_filesystem
            raise WardenError.new("Command unsupported")
          end

          self.disk_quota
        end

        def set_limit_disk(args)
          unless self.uid && self.class.quota_filesystem
            raise WardenError.new("Command unsupported")
          end

          unless args.length == 1
            raise WardenError.new("Invalid number of arguments: expected 1, got #{args.length}")
          end

          begin
            block_limit = args[0].to_i
          rescue
            raise WardenError.new("Invalid limit")
          end

          set_quota(block_limit)

          "ok"
        end

        protected

        def set_quota(block_limit)
          quota_setter = SetQuota.new
          quota_setter.user = self.uid
          quota_setter.filesystem = self.class.quota_filesystem
          quota_setter.quotas[:block][:hard] = block_limit
          quota_setter.run
          self.disk_quota = block_limit
        end

        class SetQuota < VCAP::Quota::SetQuota
          include Spawn

          def execute(command)
            sh(command)
          end
        end

        module ClassMethods

          # This needs to be set before using any containers. The users contained
          # in this pool are used to enforce disk usage limits via filesystem
          # quotas.
          #
          # NB: This imposes a hard limit on the number of containers that may exist
          #     at any one time (similar to network_pool in base.rb). Size it appropriately.
          attr_accessor :uid_pool

          # Filesystem disk quotas should be set on
          attr_accessor :quota_filesystem

          # Periodically checks that containers are within their disk usage limits. Destroys
          # any containers in violation.
          attr_accessor :quota_monitor

          def default_quota_check_interval
            5
          end

          def acquire(resources)
            super(resources)

            unless resources[:uid]
              if uid_pool
                resources[:uid] = uid_pool.acquire
              end
            end
          end

          def release(resources)
            super(resources)

            if uid = resources.delete(:uid)
              # If an uid was acquired, it should also be possible to release it again
              uid_pool.release(uid)
            end
          end

          def setup(config = {})
            if config[:quota]
              # Acquire users for quota limits
              up_config = config[:quota][:uidpool]
              self.uid_pool = Warden::Container::UidPool.acquire(up_config[:name], up_config[:count])

              # Set up the quota monitor
              self.quota_filesystem = config[:quota][:filesystem]
              check_interval = config[:quota][:check_interval] || self.default_quota_check_interval
              self.quota_monitor = QuotaMonitor.new(config[:quota][:report_quota_path],
                                                    self.quota_filesystem,
                                                    check_interval)
              self.quota_monitor.init
            end
          end
        end
      end

      include Quota

      class << self

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
        end
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
        job = Job.new(self)

        runner = File.expand_path("../../../../src/runner", __FILE__)
        socket_path = File.join(container_root_path, "/tmp/runner.sock")
        unless File.exist?(socket_path)
          error "socket does not exist: #{socket_path}"
        end

        p = DeferredChild.new(runner, "connect", socket_path, :input => script)
        p.callback { |path_inside_container|
          job.finish(File.join(container_root_path, path_inside_container))
        }
        p.errback {
          job.finish
        }

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

      class QuotaMonitor
        include Logger
        include Spawn

        def initialize(report_quota_path, filesystem, check_interval=5)
          @filesystem        = filesystem
          @callbacks         = {}
          @check_interval    = check_interval
          @initialized       = false
          @report_quota_path = report_quota_path
          @quota_check_fiber = Fiber.new do
            loop do
              start = Time.now.to_i
              check_quotas
              elapsed = Time.now.to_i - start
              next_check = @check_interval - elapsed
              if next_check <= 0
                next_check = 0.1
              end
              EM.add_timer(next_check) { @quota_check_fiber.resume }
              Fiber.yield
            end
          end
        end

        def init
          return if @initialized
          EM.add_timer(@check_interval) { @quota_check_fiber.resume }
          @initialized = true
        end

        def register(container, &blk)
          debug "Registering container for uid #{container.uid}"
          @callbacks[container.uid] = blk
        end

        def unregister(container)
          debug "Unregistering container for uid #{container.uid}"
          @callbacks.delete(container.uid)
        end

        private

        def check_quotas
          debug "Checking quotas"

          begin
            # RepQuota#run will raise an error if the repquota command fails,
            # so we are safe to ignore the status code here.
            quota_info = get_quota_usage
          rescue WardenError => we
            # This is non-fatal. Assuming the quota was set correctly, this
            # only means that the container won't be torn down in the event of
            # a quota violation.
            warn "Failed retrieving quota usage: #{we}"
            return
          end

          for uid, info in quota_info
            callback = @callbacks[uid]
            blocks_used = info[:usage][:block]
            blocks_allowed = info[:quotas][:block][:hard]
            # 0 indicates no limit
            next unless blocks_allowed > 0
            debug "Uid #{uid} used=#{blocks_used}, allowed=#{blocks_allowed} #{info}"
            if callback && (blocks_used >= blocks_allowed)
              info "Uid #{uid} is in violation (used=#{blocks_used}, allowed=#{blocks_allowed})"
              callback.call
            end
          end

          debug "Done checking quotas"
        end

        def get_quota_usage
          if @callbacks.keys.empty?
            return {}
          end

          cmd = [@report_quota_path]
          cmd << @filesystem
          cmd << @callbacks.keys
          cmd = cmd.flatten.join(' ')

          debug "Running #{cmd}"
          output = sh(cmd)

          usage = {}
          output.lines.each do |line|
            fields = line.split(/\s+/)
            fields = fields.map {|f| f.to_i }
            usage[fields[0]] = {
              :usage => {
                :block => fields[1],
                :inode => fields[5],
              },
              :quotas => {
                :block => {
                  :soft => fields[2],
                  :hard => fields[3],
                },
                :inode => {
                  :soft => fields[6],
                  :hard => fields[7],
                },
              },
            }
          end

          usage
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
