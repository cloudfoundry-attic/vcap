require "warden/errors"
require "warden/container/base"
require "warden/container/features/quota"
require "warden/container/features/cgroup"
require "warden/container/features/net_out"
require "warden/container/features/net_in"
require "warden/container/features/mem_limit"

module Warden

  module Container

    class Linux < Base

      include Features::Quota
      include Features::Cgroup
      include Features::NetIn
      include Features::NetOut
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

        args = ["-F", File.join(container_path, "ssh", "ssh_config"), "vcap@container"]
        args << { :input => script }

        child = DeferredChild.new("ssh", *args)

        child.callback do
          if child.exit_status == 255
            # SSH error, the remote end was probably killed or something
            job.resume [nil, nil, nil]
          else
            job.resume [child.exit_status, child.out, child.err]
          end
        end

        child.errback do |err|
          job.resume [nil, nil, nil]
        end

        job
      end
    end
  end
end
