require "warden/container/spawn"

module Warden

  module Container

    module Features

      module Cgroup

        def self.included(base)
          base.extend(ClassMethods)
        end

        module ClassMethods

          include Spawn

          def setup(config = {})
            super(config)

            cgroup_path = "/dev/cgroup"
            cgroup_mounts = IO.readlines("/proc/mounts").
              map(&:split).
              select { |e| e[1] == cgroup_path }. # mount point
              select { |e| e[2] == "cgroup" }     # fs type

            if cgroup_mounts.empty?
              sh "mkdir -p #{cgroup_path}"
              sh "mount -t cgroup -o blkio,devices,memory,cpuacct,cpu,cpuset none #{cgroup_path}"
            end
          end
        end

        def cgroup_root_path
          File.join("/dev/cgroup", "instance-#{self.handle}")
        end

        def get_info
          info = super

          begin
            File.open(File.join(cgroup_root_path, "memory.usage_in_bytes"), 'r') do |f|
              usage = f.read
              info['stats']['mem_usage_B'] = Integer(usage.chomp)
            end
          rescue => e
            raise WardenError.new("Failed getting memory usage: #{e}")
          end

          info
        end
      end
    end
  end
end
