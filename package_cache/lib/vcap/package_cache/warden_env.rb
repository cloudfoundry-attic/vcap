require 'logger'
require 'benchmark'
require 'warden/client'
require 'etc'

module VCAP module PackageCache end end

class VCAP::PackageCache::WardenEnv
  def initialize(runtimes = nil, logger = nil)
    @logger = logger || Logger.new(STDOUT)
    @runtimes = runtimes
    setup_warden_client
    create_container
    unless defined? @@user
      @@user = Etc.getpwuid(Process.uid).name
      @@group = Etc.getgrgid(Process.gid).name
    end
  end

  def setup_warden_client
    warden_socket_path = "/tmp/warden.sock"
    @client = Warden::Client.new(warden_socket_path)
    @client.connect
    @client.write(['ping']) #this should fail if we there is no warden present.
    result = @client.read
  end

  def add_mount_point(host_path, container_mount, mode)
    @config ||= {"bind_mounts" => []}
    @config["bind_mounts"].push([host_path, container_mount, {"mode" => mode}])
  end

  def config_container
    @runtimes.each do |runtime, path|
      mount_path = File.dirname(File.dirname(path))
      add_mount_point(mount_path, mount_path, 'ro')
    end if @runtimes
  end

  def bin_path(runtime)
    File.dirname(@runtimes[runtime])
  end

  def create_container
    config_container
    start_time = Time.now
    if @config
      @logger.debug("creating container with config #{@config.to_s}")
      @client.write(['create', @config])
    else
      @client.write(['create'])
    end
    @handle = @client.read
    end_time = Time.now
    total_time = end_time - start_time
    raise "container creation failed with #{@handle}" if @handle =~ /failure/
    @logger.debug("created container #{@handle}, took (#{total_time})")
  end

  def copy_in(src_path, dst_path)
    raise "invalid path #{src_path}" if not File.exists?(src_path)
    start_time = Time.now
    @client.write(['copy', @handle, 'in', src_path, dst_path])
    result = @client.read
    end_time = Time.now
    total_time = end_time - start_time
    raise "copy in failed" unless result == 'ok'
    @logger.debug("copied in #{dst_path}, took (#{total_time})")
  end

  def copy_out(src_path, dst_path)
    start_time = Time.now
    @client.write(['copy', @handle, 'out', src_path, dst_path, "#{@@user}:#{@@group}"])
    result = @client.read
    end_time = Time.now
    total_time = end_time - start_time
    raise "copy out failed" unless result == 'ok'
    @logger.debug("copied out #{dst_path}, took (#{total_time})")
  end

  def file_exists?(path)
    cmd = "test -e #{path} && echo true"
    _,out,_ = run(cmd)
    out.chop == 'true'
  end

  def run(cmd)
    start_time = Time.now
    @client.write(['run', @handle, cmd])
    result = @client.read
    end_time = Time.now
    total_time = end_time - start_time
    @logger.debug("run #{cmd}:took (#{total_time}) returned: #{result.to_s}")
    result
  end

  def destroy!
    @client.write(['destroy', @handle])
    result = @client.read
    @logger.error("failed to clean up container #{@handle}.") if result != 'ok'
  end
end

