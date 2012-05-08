require "thread"
require "tmpdir"
require "warden/client"
require "yajl"

require "vcap/concurrency/promise"
require "vcap/stager/plugin_runner/base"
require "vcap/stager/util"

require "vcap/logging"

class VCAP::Stager::PluginRunner::WardenBased < VCAP::Stager::PluginRunner::Base
  PLUGIN_LOADER_PATH    = VCAP::Stager::Util.path("assets", "plugin_loader")
  RUNTIME_TEMPLATE_PATH = VCAP::Stager::Util.path("assets", "runtime_path.erb")

  CONTAINER_SIZE_MB = 1024

  # Helper class to trace all operations on a specific container
  class Container
    def initialize(client, handle, logger)
      @client = client
      @handle = handle
      @logger = logger
    end

    def method_missing(method, *args, &blk)
      @logger.debug("handle #{@handle}: #{method} #{args}")

      my_args = args.dup.unshift(@handle)

      @client.send(method, *my_args, &blk)
    end

    def run_with_timeout(cmd, timeout, opts = {})
      barrier = VCAP::Concurrency::Promise.new
      result = VCAP::Concurrency::Promise.new

      watchdog_thread = Thread.new do
        begin
          # Wait for the command to complete or the timeout to occur
          barrier.resolve(timeout)

          result.deliver(false)
        rescue VCAP::Concurrency::TimeoutError
          @logger.warn("Timeout occurred for handle #{@handle}: (#{timeout}s)")

          force_stop(cmd)

          result.deliver(true)
        end
      end

      watchdog_thread.abort_on_exception = true

      run_res = run(cmd, opts)

      # Wake up the watchdog thread
      barrier.deliver

      # Determine whether or not we timed out
      timed_out = result.resolve

      watchdog_thread.join

      [timed_out, run_res].flatten
    end

    def force_stop(cmd)
      # Internal client may be blocked on a link. We create a new client
      # that stops the container out-of-band, thus waking up our link.
      client = Warden::Client.new(@client.path)

      client.connect

      begin
        # Should warden provide a way to terminate jobs?
        @logger.debug("handle #{@handle}: stop")

        client.stop(@handle)

      rescue Warden::Client::ServerError => e
        # Container may have gone away.
        raise e if e !~ /unknown handle/
      end
    end
  end

  # Container object representing the directory structure of the home directory
  # inside the container. Currently, it has the following layout (paths with a
  # trailing `?' are optional):
  #
  # ~/
  #   bin/
  #     runtime_path
  #     plugin_loader
  #   helpers/
  #     environment?
  #   unstaged_app/
  #     ...
  #   staged_app/
  #     ...
  #   app_properties.json
  class FsTemplate

    attr_reader :base_path,
                :bin_path,
                :runtime_script_path,
                :plugin_loader_path,
                :helpers_path,
                :environment_path,
                :unstaged_path,
                :staged_path,
                :app_properties_path

    def initialize(base_path)
      @base_path           = base_path
      @bin_path            = File.join(@base_path, "bin")
      @runtime_script_path = File.join(@bin_path, "runtime_path")
      @plugin_loader_path  = File.join(@bin_path, "plugin_loader")
      @helpers_path        = File.join(@base_path, "helpers")
      @environment_path    = File.join(@helpers_path, "environment")
      @unstaged_path       = File.join(@base_path, "unstaged")
      @staged_path         = File.join(@base_path, "staged")
      @app_properties_path = File.join(@base_path, "app_properties.json")
    end

    def build(properties, runtimes, opts = {})
      [@unstaged_path, @staged_path, @bin_path, @helpers_path].each do |d|
        FileUtils.mkdir_p(d)
      end

      FileUtils.cp(PLUGIN_LOADER_PATH, @plugin_loader_path)
      FileUtils.chmod(0755, @plugin_loader_path)

      write_properties_file(@app_properties_path, properties)

      write_runtime_script(@runtime_script_path, runtimes)

      if opts[:environment_path]
        FileUtils.cp(opts[:environment_path], @environment_path)
      end

      nil
    end

    private

    def write_properties_file(path, props)
      File.open(path, "w+") { |f| f.write(Yajl::Encoder.encode(props)) }

      nil
    end

    def write_runtime_script(path, runtimes)
      template = ERB.new(File.read(RUNTIME_TEMPLATE_PATH))

      contents = template.result(binding())

      File.open(path, "w+") { |f| f.write(contents) }

      FileUtils.chmod(0755, path)

      nil
    end
  end

  # @param [Hash] opts
  # @option opts [String] :socket_path  Path to the unix domain socket that the
  # warden is listening on.
  # @option opts [Hash] :plugins  Map of plugin name to directory housing the
  # corresponding staging plugin.
  # @option opts [String :environment_path  Optional path to a script that will
  # be sourced prior to invoking the staging plugin.
  # @option opts [Array<String>] :bind_mounts Optional list of paths to be bind
  # mounted inside the container.
  # @option opts [Hash] :runtimes Map of runtime name to directory. The
  # directory will be bind-mounted inside the container.
  # @option opts [Integer] :my_uid Optional uid that artifacts copied out of
  # the container will be chowned to. Defaults to the uid of whoever is running
  # the process.
  # @option [String] :manifests_dir Optional directory housing staging manifests
  # which will be bind mounted inside the container.
  def initialize(opts = {})
    @bind_mounts      = opts[:bind_mounts] || []
    @environment_path = opts[:environment_path]
    @manifests_dir    = opts[:manifests_dir]
    @socket_path      = opts[:socket_path] || "/tmp/warden.sock"
    @plugins          = opts[:plugins] || {}
    @runtimes         = opts[:runtimes] || {}
    @my_uid           = opts[:my_uid] || `id -u`.chomp
    @logger = VCAP::Logging.logger("vcap.stager.plugin_runner.warden_based")
  end

  def stage(properties, src_dir, dst_dir, opts = {})
    framework = properties["framework"].to_sym

    plugin_path = @plugins[framework]

    if plugin_path.nil? || !File.exist?(plugin_path)
      return { :error => "No plugin found for framework '#{framework}'" }
    end

    client = ::Warden::Client.new(@socket_path)

    client.connect

    # Map of path => resolved path
    bind_mounts = [@bind_mounts, @runtimes.values, plugin_path, @manifests_dir] \
                    .flatten                                                    \
                    .uniq                                                       \
                    .select { |p| !p.nil? }                                     \
                    .inject({}) { |h, p| h[p] = File.realpath(p); h }

    handle = client.create(
      "disk_size_mb" => CONTAINER_SIZE_MB,
      "bind_mounts"  => bind_mounts.map { |_, p| [p, p, { "mode" => "ro" } ] })

    container = Container.new(client, handle, @logger)

    # Preserve symlinks for bind mounts
    bind_mounts.each do |path, real_path|
      next if path == real_path

      path_dirname = File.dirname(path)

      st, _ = container.run("mkdir -p #{path_dirname}", "privileged" => true)
      if st != 0
        return { :error => "Failed setting up container" }
      end

      container.run("ln -s #{real_path} #{path}", "privileged" => true)
      if st != 0
        return { :error => "Failed setting up container" }
      end
    end

    host_tmpl = FsTemplate.new(Dir.mktmpdir)
    cont_tmpl = FsTemplate.new("/home/vcap/")

    # Create the directory on the host
    host_tmpl.build(properties, @runtimes,
                    :environment_path => @environment_path)

    # Copy it to the container in one go.
    container.copy("in", "#{host_tmpl.base_path}/", cont_tmpl.base_path)

    # Copy in the unstaged bits
    container.copy("in", "#{src_dir}/", cont_tmpl.unstaged_path)

    # Finally, run the staging plugin.
    stage_cmd = [cont_tmpl.plugin_loader_path,
                 File.join(plugin_path, "bin", "stage"), # bind-mounted in
                 cont_tmpl.unstaged_path,
                 cont_tmpl.staged_path,
                 cont_tmpl.app_properties_path]

    stage_cmd << @manifests_dir if @manifests_dir
    stage_cmd = stage_cmd.join(" ")

    timed_out, st, stdout, stderr =\
      if opts[:timeout]
        container.run_with_timeout(stage_cmd, opts[:timeout])
      else
        container.run(stage_cmd).unshift(false)
      end

    if timed_out
      stderr ||= ""
      stderr += "\nStaging timed out after #{opts[:timeout]}s."
    end

    @logger.info("Staging plugin exited with status #{st}")

    @logger.info("stdout:")
    @logger.info(stdout)

    @logger.info("stderr:")
    @logger.info(stderr)

    if timed_out || (st != 0)
      return { :error => stderr, :log => stdout }
    end

    container.copy("out", "#{cont_tmpl.staged_path}/", dst_dir, @my_uid)

    { :log => stdout }

  rescue ::EOFError => e
    @logger.error("Error talking to the warden: #{e}")
    @logger.error(e)

    { :error => "Internal error" }

  rescue Warden::Client::ServerError => e
    @logger.error("Received an error reply from the warden: #{e}")
    @logger.error(e)

    { :error => "Internal error" }

  ensure
    FileUtils.rm_rf(host_tmpl.base_path) if host_tmpl

    if handle
      begin
        @logger.debug("handle #{handle}: destroy")

        client.destroy(handle)
      rescue => e
        @logger.error("Failed destroying handle #{handle}: #{e}")
        @logger.error(e)
      end
    end
  end
end
