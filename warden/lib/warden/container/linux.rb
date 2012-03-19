require "warden/errors"
require "warden/container/base"
require "warden/container/features/cgroup"
require "warden/container/features/net"
require "warden/container/features/mem_limit"

module Warden

  module Container

    class Linux < Base

      include Features::Cgroup
      include Features::Net
      include Features::MemLimit

      class << self

        def setup(config = {})
          unless Process.uid == 0
            raise WardenError.new("linux containers require root privileges")
          end

          super(config)
        end
      end

      def env
        env = {
          "id" => handle,
          "network_gateway_ip" => gateway_ip.to_human,
          "network_container_ip" => container_ip.to_human,
          "network_netmask" => self.class.network_pool.netmask.to_human,
        }
        env
      end

      def env_command
        "env #{env.map { |k, v| "#{k}=#{v}" }.join(" ")}"
      end

      def do_create
        sh "#{env_command} #{root_path}/create.sh #{handle}", :timeout => nil
        debug "container created"
        sh "#{container_path}/start.sh", :timeout => nil
        debug "container started"
      end

      def do_stop
        sh "#{container_path}/stop.sh"
      end

      def do_destroy
        sh "#{root_path}/destroy.sh #{handle}", :timeout => nil
        debug "container destroyed"
        sh "rm -rf #{container_path}", :timeout => nil
        debug "container removed"
      end

      def create_job(script)
        job = Job.new(self)

        # -T: Never request a TTY
        # -F: Use configuration from <container_path>/ssh/ssh_config
        args = ["-T", "-F", File.join(container_path, "ssh", "ssh_config"), "vcap@container"]
        args << { :input => script }

        child = DeferredChild.new("ssh", *args)

        child.callback do
          if child.exit_status == 255
            # SSH error, the remote end was probably killed or something
            job.resume [nil, nil, nil]
          else
            job.resume [child.exit_status, child.stdout, child.stderr]
          end
        end

        child.errback do |err|
          job.resume [nil, nil, nil]
        end

        job
      end

      def do_copy_in(src_path, dst_path)
        perform_rsync(src_path, "vcap@container:#{dst_path}")

        "ok"
      end

      def do_copy_out(src_path, dst_path, owner=nil)
        perform_rsync("vcap@container:#{src_path}", dst_path)

        if owner
          sh "chown -R #{owner} #{dst_path}"
        end

        "ok"
      end

      private

      def perform_rsync(src_path, dst_path)
        ssh_config_path = File.join(container_path, "ssh", "ssh_config")
        cmd = ["rsync -e 'ssh -T -F #{ssh_config_path}'",
               "-r",           # Recursive copy
               "-p",           # Preserve permissions
               "--links",      # Preserve symlinks
               src_path,
               dst_path].join(" ")
        sh(cmd, :timeout => nil)
      end

    end
  end
end
