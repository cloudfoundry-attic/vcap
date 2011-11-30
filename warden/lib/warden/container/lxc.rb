require "warden/errors"
require "warden/container/base"
require "warden/container/script_handler"
require "warden/container/remote_script_handler"

module Warden

  module Container

    class LXC < Base

      def self.setup
        unless Process.uid == 0
          raise WardenError.new("warden needs to run as root to use lxc")
        end

        unless IO.readlines("/proc/mounts").find { |e| e =~ %r/ cgroup /i }
          begin
            FileUtils.mkdir_p("/dev/cgroup")
          rescue Errno::EACCES
            raise WardenError.new("unable to create mount point for cgroup vfs")
          end

          unless system("mount -t cgroup none /dev/cgroup")
            raise WardenError.new("unable to mount cgroup vfs")
          end
        end
      end

      def container_root_path
        File.join(container_path, "union")
      end

      def env
        {
          "network_gateway_ip" => gateway_ip.to_human,
          "network_container_ip" => container_ip.to_human,
          "network_netmask" => self.class.network_pool.netmask.to_human
        }
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

      def do_destroy
        # Stop container
        sh "#{container_path}/stop.sh"
        debug "container stopped"

        # Destroy container
        sh "rm -rf #{container_path}"
        debug "container destroyed"
      end

      def create_job(script)
        socket_path = File.join(container_root_path, "/tmp/runner.sock")
        unless File.exist?(socket_path)
          error "socket does not exist: #{socket_path}"
        end

        job = Job.new(self)
        handler = ::EM.connect_unix_domain(socket_path, RemoteScriptHandler)

        # Send path to job artifact directory on the first line
        handler.send_data(job.path + "\n")

        # The remainder of stdin will be consumed by a subshell
        handler.send_data(script + "\n")

        # Make bash exit without losing the exit status. This can otherwise
        # be done by shutting down the write side of the socket, causing EOF
        # on stdin for the remote. However, EM doesn't do shutdown...
        handler.send_data "exit $?\n"

        handler.callback { job.finish }

        job
      end
    end
  end
end
