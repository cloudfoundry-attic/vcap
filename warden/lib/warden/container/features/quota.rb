require "vcap/quota"
require "warden/errors"
require "warden/container/spawn"
require "warden/container/uid_pool"

module Warden

  module Container

    module Features

      module Quota

        include Spawn

        def self.included(base)
          base.extend(ClassMethods)
        end

        def initialize(*args)
          super(*args)

          if self.class.quota_monitor
            # Reset quota for user
            set_quota(0)

            self.class.quota_monitor.register(self) do
              self.warn "Disk quota (#{self.limits['disk']}) exceeded, stopping"
              self.events << 'quota_exceeded'
              self.class.quota_monitor.unregister(self)
              if self.state == State::Active
                self.stop
              end
            end
          end

          on(:after_stop) {
            if self.class.quota_monitor
              self.class.quota_monitor.unregister(self)
              set_quota(0)
            end
          }
        end

        def uid
          @resources[:uid]
        end

        def get_limit_disk
          unless self.uid && self.class.quota_filesystem
            raise WardenError.new("Command unsupported")
          end
          self.limits['disk'] ||= 0
          self.limits['disk']
        end

        def set_limit_disk(args)
          unless self.uid && self.class.quota_filesystem
            raise WardenError.new("Command unsupported")
          end

          unless args.length == 1
            raise WardenError.new("Invalid number of arguments: expected 1, got #{args.length}")
          end

          begin
            block_limit = Integer(args[0])
          rescue
            raise WardenError.new("Invalid limit")
          end

          set_quota(block_limit)

          "ok"
        end

        def get_info
          info = super

          if self.class.quota_monitor
            info['stats']['disk_usage_B'] = 1024 * self.class.quota_monitor.usage_for_container(self)
          end

          info
        end

        protected

        def set_quota(block_limit)
          quota_setter = SetQuota.new
          quota_setter.user = self.uid
          quota_setter.filesystem = self.class.quota_filesystem
          quota_setter.quotas[:block][:hard] = block_limit
          quota_setter.run
          self.limits['disk'] = block_limit
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
            super(config)

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

          def usage_for_container(container)
            quota_info = get_quota_usage([container.uid])
            if quota_info[container.uid]
              quota_info[container.uid][:usage][:block]
            else
              nil
            end
          end

          private

          def check_quotas
            debug "Checking quotas"

            begin
              # RepQuota#run will raise an error if the repquota command fails,
              # so we are safe to ignore the status code here.
              quota_info = get_quota_usage(@callbacks.keys)
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

          def get_quota_usage(uids)
            return {} if uids.empty?

            cmd = [@report_quota_path]
            cmd << @filesystem
            cmd << uids
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
      end
    end
  end
end
