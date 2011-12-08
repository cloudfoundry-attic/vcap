require "warden/errors"
require "warden/logger"
require "sleepy_penguin"

module Warden

  module Container

    module Features

      module MemLimit

        class OomNotifier < EM::Connection

          include Logger

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
            info "OOM condition occurred inside container #{self.container.handle}"

            # We rely on container destruction to unregister ourselves from
            # the event loop and close our event fd (by calling #unregister).
            #
            # NB: This is executed on the next tick of the reactor to avoid
            #     doing a detach inside the read callback.
            EM.next_tick do
              Fiber.new do
                self.container.destroy
              end.resume
            end
          end

          def unregister
            debug "Unregistering OOM Notifier for container '#{self.container.handle}'"
            @io.close rescue nil
            detach
          end
        end # OomNotifier

        def mem_limit
          @mem_limit ||= 0
        end

        def mem_limit=(v)
          @mem_limit = v
        end

        def get_limit_mem
          self.mem_limit
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
            mem_limit_path = File.join(self.cgroup_root_path, "memory.limit_in_bytes")
            File.open(mem_limit_path, 'w') do |f|
              f.write(mem_limit.to_s)
            end
            self.mem_limit = mem_limit
          rescue => e
            raise WardenError.new("Failed setting memory limit: #{e}")
          end

          unless @oom_notifier
            @oom_notifier = OomNotifier.for_container(self)
            on(:before_destroy) do
              @oom_notifier.unregister
              @oom_notifier = nil
            end
          end

          "ok"
        end
      end
    end
  end
end
