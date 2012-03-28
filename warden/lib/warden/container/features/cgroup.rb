require "warden/container/spawn"

module Warden

  module Container

    module Features

      module Cgroup

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
