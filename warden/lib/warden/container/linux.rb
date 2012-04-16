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

        attr_reader :bind_mount_script_template

        def setup(config = {})
          unless Process.uid == 0
            raise WardenError.new("linux containers require root privileges")
          end

          super(config)

          sh *[ %{env},
            %{ALLOW_NETWORKS=%s} % allow_networks.join(" "),
            %{DENY_NETWORKS=%s} % deny_networks.join(" "),
            %{%s/setup.sh} % root_path ]
        end
      end

      def initialize(resources, config = {})
        super(resources, config)
        @config.merge!(sanitize_config(config.dup))
      end

      def env
        env = {
          "id" => handle,
          "network_host_ip" => host_ip.to_human,
          "network_container_ip" => container_ip.to_human,
          "network_netmask" => self.class.network_pool.netmask.to_human,
          "disk_size_mb" => @config[:disk_size_mb],
        }
        env
      end

      def env_command
        "env #{env.map { |k, v| "#{k}=#{v}" }.join(" ")}"
      end

      def do_create
        sh "#{env_command} #{root_path}/create.sh #{handle}", :timeout => nil
        debug "container created"

        write_bind_mount_commands
        debug "wrote bind mount commands"

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

      def sanitize_config(config)
        result = {}

        bind_mounts = sanitize_config_bind_mounts(config.delete("bind_mounts"))
        result[:bind_mounts] = bind_mounts

        disk_size_mb = Server.container_disk_size_mb
        disk_size_mb = config.delete("disk_size_mb") if config.has_key?("disk_size_mb")
        disk_size_mb = sanitize_config_disk_size_mb(disk_size_mb)
        result[:disk_size_mb] = disk_size_mb

        result
      end

      def sanitize_config_bind_mounts(bind_mounts)
        bind_mounts ||= []

        # Raise when it is not an Array
        if !bind_mounts.is_a?(Array)
          raise WardenError.new("Expected `bind_mounts` to hold an array.")
        end

        # Transform entries
        bind_mounts = bind_mounts.map do |src_path, dst_path, options|
          options ||= {}

          if !src_path.is_a?(String)
            raise WardenError.new("Expected `src_path` to be a string.")
          end

          if !dst_path.is_a?(String)
            raise WardenError.new("Expected `dst_path` to be a string.")
          end

          if !options.is_a?(Hash)
            raise WardenError.new("Expected `options` to be a hash.")
          end

          # Fix up destination path to be an absolute path inside the union
          dst_path = File.join(container_path,
                                "union",
                                dst_path.slice(1, dst_path.size - 1))

          # Check that the mount mode -- if given -- is "ro" or "rw"
          if options.has_key?("mode")
            unless ["ro", "rw"].include?(options["mode"])
              raise WardenError, [
                  %{Invalid mode for bind mount "%s".} % src_path,
                  %{Must be one of "ro", "rw".}
                ].join(" ")
            end

            options[:mode] = options.delete("mode")
          end

          [src_path, dst_path, options]
        end

        # Filter nil entries
        bind_mounts.compact
      end

      def sanitize_config_disk_size_mb(disk_size_mb)
        if disk_size_mb.is_a?(String)
          begin
            disk_size_mb = Integer(disk_size_mb)
          rescue ArgumentError
            raise WardenError.new("Expected `disk_size_mb` to be an integer.")
          end
        end

        # Must be an integer
        if !disk_size_mb.kind_of?(Integer)
          raise WardenError.new("Expected `disk_size_mb` to be an integer.")
        end

        disk_size_mb
      end

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

      def write_bind_mount_commands
        File.open(File.join(container_path, "hook-parent-before-clone.sh"), "a") do |file|
          file.puts
          file.puts

          @config[:bind_mounts].each do |src_path, dst_path, options|
            file.puts "mkdir -p #{dst_path}" % [dst_path]
            file.puts "mount -n --bind #{src_path} #{dst_path}"

            if options[:mode]
              file.puts "mount -n --bind -o remount,#{options[:mode]} #{src_path} #{dst_path}"
            end
          end
        end
      end
    end
  end
end
