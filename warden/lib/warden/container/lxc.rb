require "warden/errors"
require "warden/container/base"
require "warden/container/script_handler"
require "warden/container/remote_script_handler"

require "fiber"
require "set"

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

      def initialize
        super

        @created = false
        @destroyed = false
      end

      def path
        File.join(Server.container_root, ".instance-#{handle}")
      end

      def rootfs
        File.join(path, "union")
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

      def create
        if @created
          raise WardenError.new("container is already created")
        end

        @created = true

        # Create container
        command = "#{env_command} root/create.sh #{handle}"
        debug command
        handler = ::EM.popen(command, ScriptHandler)
        handler.yield { error "could not create container" }
        debug "container created"

        # Start container
        command = File.join(path, "start.sh")
        debug command
        handler = ::EM.popen(command, ScriptHandler)
        handler.yield { error "could not start container" }
        debug "container started"

        # Any client should now be able to look this container up
        register
      end

      def destroy
        unless @created
          raise WardenError.new("container is not yet created")
        end

        if @destroyed
          raise WardenError.new("container is already destroyed")
        end

        @destroyed = true

        # Clients should no longer be able to look this container up
        unregister

        # Stop container
        command = File.join(path, "stop.sh")
        debug command
        handler = ::EM.popen(command, ScriptHandler)
        handler.yield { error "could not stop container" }
        debug "container stopped"

        # Destroy container
        command = "rm -rf #{path}"
        debug command
        handler = ::EM.popen(command, ScriptHandler)
        handler.yield { error "could not destroy container" }
        debug "container destroyed"

        # Release network address only if the container has successfully been
        # destroyed. If not, the network address will "leak" and cannot be
        # reused until this process is restarted. We should probably add extra
        # logic to destroy a container in a failure scenario.
        ::EM.add_timer(5) {
          Server.network_pool.release(network)
        }
      end

      def run(script)
        unless @created
          raise WardenError.new("container is not yet created")
        end

        if @destroyed
          raise WardenError.new("container is already destroyed")
        end

        socket_path = File.join(path, "union/tmp/runner.sock")
        unless File.exist?(socket_path)
          error "socket does not exist: #{socket_path}"
        end

        handler = ::EM.connect_unix_domain(socket_path, RemoteScriptHandler, script)
        result = handler.yield { error "runner unexpectedly terminated" }
        debug "runner successfully terminated: #{result.inspect}"

        # Mix in path to the container's rootfs
        status, stdout_path, stderr_path = result
        stdout_path = File.join(rootfs, stdout_path) if stdout_path
        stderr_path = File.join(rootfs, stderr_path) if stderr_path
        [status, stdout_path, stderr_path]
      end
    end
  end
end
