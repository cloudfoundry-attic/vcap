require "warden/errors"
require "warden/container/base"
require "warden/container/features/quota"
require "warden/container/features/cgroup"
require "warden/container/features/net_out"
require "warden/container/features/net_in"
require "warden/container/features/mem_limit"

module Warden

  module Container

    class LXC < Base

      include Features::Quota
      include Features::Cgroup
      include Features::NetIn
      include Features::NetOut
      include Features::MemLimit

      class << self

        def setup(config = {})
          unless Process.uid == 0
            raise WardenError.new("lxc requires root privileges")
          end

          super(config)
        end
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

      def do_stop
        # Kill all processes in the container
        sh "#{container_path}/killprocs.sh"
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
    end
  end
end
