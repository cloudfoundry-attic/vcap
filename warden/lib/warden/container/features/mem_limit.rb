require "warden/errors"
require "warden/logger"
require "sleepy_penguin"

module Warden

  module Container

    module Features

      module MemLimit

        class OomNotifier < EM::Connection
          class << self
            def for_container(container)
              cgroup_root = container.cgroup_root_path
              cio = File.open(File.join(cgroup_root, 'memory.oom_control'), File::RDONLY)
              eio = SleepyPenguin::EventFD.new(0, :NONBLOCK)

              ctrl_file = File.open(File.join(cgroup_root, 'cgroup.event_control'), File::WRONLY)
              ctrl_file.syswrite(["#{eio.fileno} #{cio.fileno} 1"].pack("Z*"))
              ctrl_file.close
              cio.close

              notifier = EM.attach(eio, OomNotifier)
              notifier.container = container
              notifier
            end
          end

          def container=(container)
            @container = container
          end

          def container
            @container
          end

          # We don't care about the data written to us. Its only purpose is to
          # notify us that a process inside the container OOMed
          def receive_data(_)
            # We rely on container destruction to unregister ourselves from
            # the event loop and close our event fd (by calling #unregister).
            #
            # NB: This is executed on the next tick of the reactor to avoid
            #     doing a detach inside the read callback.
            EM.next_tick do
              Fiber.new do
                self.container.oomed
              end.resume
            end
          end

          def unregister
            detach
            @io.close rescue nil
          end
        end # OomNotifier

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
              @oom_notifier = OomNotifier.for_container(self)
              on(:after_stop) do
                if @oom_notifier
                  self.debug "Unregistering OOM Notifier for container '#{self.handle}'"
                  @oom_notifier.unregister
                  @oom_notifier = nil
                end
              end
            end

            mem_limit_path = File.join(self.cgroup_root_path, "memory.limit_in_bytes")
            File.open(mem_limit_path, 'w') do |f|
              f.write(mem_limit.to_s)
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
