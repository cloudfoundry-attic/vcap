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
              sh "mount -t cgroup none #{cgroup_path}"
            end
          end
        end
      end
    end
  end
end
