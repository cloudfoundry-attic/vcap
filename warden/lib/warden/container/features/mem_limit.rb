require "warden/errors"
require "warden/logger"
require "warden/container/spawn"

module Warden

  module Container

    module Features

      module MemLimit

        class OomNotifier

          include Spawn
          include Logger

          attr_reader :container

          def initialize(container)
            @container = container

            oom_notifier_path = File.expand_path("../../../../../src/oom/oom", __FILE__)
            @child = DeferredChild.new(oom_notifier_path, container.cgroup_root_path)

            # Zero exit status means a process OOMed, non-zero means an error occurred
            @child.callback do
              if @child.success?
                Fiber.new do
                  container.oomed
                end.resume
              else
                debug "stderr: #{@child.err}"
              end
            end

            # Don't care about errback, nothing we can do
          end

          def unregister
            # Overwrite callback
            @child.callback do
              # Nothing
            end

            # TODO: kill child
          end
        end

        def oomed
          self.warn "OOM condition occurred inside container #{self.handle}"

          self.events << 'oom'
          if self.state == State::Active
            self.stop
          end
        end

        def get_limit_mem
          self.limits['mem'] ||= 0
          self.limits['mem']
        end

        def set_limit_mem(args)
          unless args.length == 1
            raise WardenError.new("Invalid number of arguments: expected 1, got #{args.length}")
          end

          begin
            mem_limit = Integer(args[0])
          rescue
            raise WardenError.new("Invalid limit")
          end

          begin

            # Need to set up the oom notifier before we set the memory limit to
            # avoid a race between when the limit is set and when the oom
            # notifier is registered.
            unless @oom_notifier
              @oom_notifier = OomNotifier.new(self)
              on(:after_stop) do
                if @oom_notifier
                  self.debug "Unregistering OOM Notifier for container '#{self.handle}'"
                  @oom_notifier.unregister
                  @oom_notifier = nil
                end
              end
            end

            ["memory.limit_in_bytes", "memory.memsw.limit_in_bytes"].each do |path|
              File.open(File.join(cgroup_root_path, path), 'w') do |f|
                f.write(mem_limit.to_s)
              end
            end

            self.limits['mem'] = mem_limit
          rescue => e
            raise WardenError.new("Failed setting memory limit: #{e}")
          end

          "ok"
        end
      end
    end
  end
end
