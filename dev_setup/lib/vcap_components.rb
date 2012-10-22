# Copyright (c) 2009-2011 VMware, Inc.
#

require 'yaml'
require 'fileutils'

require File.expand_path("./vcap_common.rb", File.dirname(__FILE__))

class Component
  @@named_components = {}

  attr :name

  def self.create(name, configuration_file=nil)
    sub_class = @@named_components[name]
    if sub_class
      sub_class.new(name, configuration_file)
    else
      nil
    end
  end

  def self.register(name)
    @@named_components[name] = self
  end

  def self.getNamedComponents()
    @@named_components
  end

  def initialize(name, configuration_file = nil)
    @name = name
    @configuration_path = configuration_file || get_configuration_path
  end

  def is_cloud_controller?
    @name =~ /cloud_controller/i
  end

  def is_router?
    @name =~ /router/i
  end

  def to_s
    name
  end

  def exists?
    File.exists? get_path
  end

  def vcap_bin
    DIR
  end

  def get_path
    @path ||= File.join(vcap_bin, name)
  end

  def configuration_file_in
    $config_dir ||= ENV['CLOUD_FOUNDRY_CONFIG_PATH']
    $config_dir
  end

  def get_configuration_path
    if @configuration_path.nil?
      if configuration_file_in
        @configuration_path = File.join(configuration_file_in, "#{name}.yml")
      else
        @configuration_path = File.join(vcap_bin, "..", name, "config", "#{name}.yml")
      end
    end
    @configuration_path
  end

  def configuration
    @configuration ||= YAML.load(File.read(get_configuration_path))
  end

  def pid_file
    configuration["pid"] || raise("#{get_configuration_path} does not specify location of pid file")
  end

  def log_file?
    !configuration["log_file"].nil?
  end

  def log_file
    log_file = configuration["log_file"]
    log_file || File.join($log_dir, "#{name}.log")
  end

  def pid
    if File.exists?(pid_file)
      body = File.read(pid_file)
      body.to_i if body
    end
  end

  def running?
    running = false
    # Only evaluate 'pid' once per call to 'running?'
    if procid = pid
      running = `ps -o rss= -p #{procid}`.length > 0
    end
    running
  end

  def component_start_path
    exec_path = (get_path).dup
    exec_path << " -c #{get_configuration_path}"
    if is_router? && $port
      exec_path << " -p #{$port}"
    end
    exec_path
  end

  def start
    if !running?

      pid = fork do
        # Capture STDOUT when no log file is configured
        if !log_file?
          stdout = File.open(log_file, 'a')
          stdout.truncate(0)
          STDOUT.reopen(stdout)
          stderr = File.open(log_file, 'a')
          STDERR.reopen(stderr)
        end
        # Make sure db is setup, this is slow and we should make it faster, but
        # should help for now.
        if is_cloud_controller?
          cc_dir = File.expand_path(File.join($vcap_home, 'cloud_controller', 'cloud_controller'))
          Dir.chdir(cc_dir) { `bundle exec rake db:migrate` }
        end
        exec("#{component_start_path}")
      end

      Process.detach(pid)

      start = Time.now
      while ((Time.now - start) < 20)
        break if running?
        sleep (0.25)
      end
    end

    status

    if !running?
      if File.exists?(log_file)
        log = File.read(log_file)
        STDERR.puts "LOG:\n #{log}" if !log.empty?
      end
    end
  end

  def stop
    return status unless running?

    kill = "kill -TERM #{pid}"
    `#{kill} 2> /dev/null`

    if $? != 0
      STDERR.puts "#{'Failed'.red} to stop #{name}, possible permission problem\?"
      return
    end

    # Return status if we succeeded in stopping
    return status unless running?

    if running?
      sleep(0.25)
      if running?
        kill = "kill -9 #{pid}"
        `#{kill} 2> /dev/null`
      end
    end
    status
  end

  def status
    status = running? ? 'RUNNING'.green : 'STOPPED'.red
    puts "#{name.ljust(30)}:\t #{status}"
  end

end

class CoreComponent < Component
  def core?
    true
  end

  def initialize(name, configuration_file = nil)
    @path ||= File.join($vcap_home, name, "bin", name)
    super
  end
end

class StagerComponent < CoreComponent
  def pid_file
    configuration["pid_filename"] || raise("#{get_configuration_path} does not specify location of pid file")
  end
end

class UAAComponent < CoreComponent
  def initialize(*args)
    @path = File.join($vcap_home, "bin", "uaa")
    super
  end
end

class ACMComponent < CoreComponent
  def initialize(*args)
    @path = File.join($vcap_home, "bin", "acm")
    super
  end
end

class CCComponent < CoreComponent
  def initialize(*args)
    @path = File.join($vcap_home, "cloud_controller", "cloud_controller", "bin", "cloud_controller")
    super
  end
end

class HMComponent < CoreComponent
  def initialize(*args)
    @path = File.join($vcap_home, "cloud_controller", "health_manager", "bin", "health_manager")
    super
  end
end

class ServicesRedisComponent < Component
  def services_redis?
    true
  end

  def get_path
    return @path if @path
    if $config_dir.nil?
      raise "Fail to get path of redis-server for ServicesRedisComponent #{name}"
    end
    @path = File.join($config_dir, "..", "deploy", "redis", "bin", "redis-server")
  end

  def get_configuration_path
    return @configuration_path if @configuration_path
    if $config_dir.nil?
      raise "Fail to get configuration file of redis-server for ServicesRedisComponent #{name}"
    end
    @configuration_path = File.join($config_dir, "#{name}.conf")
  end

  def component_start_path
     exec_path = "#{get_path.dup} #{get_configuration_path}"
  end

  def log_file?
    config_file = get_configuration_path
    ret = `cat #{config_file} | grep logfile`.strip
    if ret.nil? || ret.empty?
      `echo "logfile #{log_file}" >> #{config_file}`
    end
    super
  end

  def pid_file
    config_file = get_configuration_path
    ret = `cat #{config_file} | grep pidfile | awk '{print $2}'`.strip
    if ret.nil? || ret.empty?
      raise("#{get_configuration_path} does not specify location of pid file")
    end
    ret
  end
end

class ServiceComponent < Component
  def service?
    true
  end

  def node?
    @name =~ /_node/i
  end

  def gateway?
    @name =~ /_gateway/i
  end

  def worker?
    @name =~ /_worker/i
  end

  def pid_file
    return super unless worker?
    pre = name.sub(/_worker/, '')
    tmp_node_pid_file = Component.create("#{pre}_node").pid_file
    pid_dir = File.dirname(tmp_node_pid_file)
    return File.join(pid_dir, "#{name}.pid")
  end

  def get_path
    return @path if @path
    pre = name.sub(/_node|_gateway|_worker/,'')
    # mapping 'rabbitmq' in dev_setup to 'rabbit' in services
    pre = 'rabbit' if pre == 'rabbitmq'
    bin_name = name.index('rabbitmq')? name.sub(/mq/, '') : name
    @path = File.join(vcap_bin, "../services", pre, "bin", bin_name)
  end

  def get_configuration_path
    @configuration_path ||= (File.join(configuration_file_in, "#{name}.yml") if configuration_file_in)
    unless @configuration_path && File.exist?(@configuration_path)
      pre = name.sub(/_node|_gateway|_worker/,'')
      # mapping 'rabbitmq' in dev_setup to 'rabbit' in services
      pre = 'rabbit' if pre == 'rabbitmq'
      @configuration_path = File.join(vcap_bin, "../services", pre, "config", "#{name}.yml")
    end
    @configuration_path
  end

  def component_start_path
    return super unless worker?
    # FIXME
    # only support single worker
    exec_path = (get_path).dup
    config_dir_path = File.dirname(get_configuration_path)
    exec_path = "env CLOUD_FOUNDRY_CONFIG_PATH=#{config_dir_path} PIDFILE=#{pid_file} #{exec_path} 1"
    return exec_path
  end

end

class ServiceAuxiliaryComponent < Component
  def service_auxiliary?
    true
  end

  def get_path
    @path ||= File.join(vcap_bin, "../services", name, "bin", name)
  end

  def get_configuration_path
    @configuration_path ||= (File.join(configuration_file_in, "#{name}.yml") if configuration_file_in)
    unless @configuration_path && File.exist?(@configuration_path)
      @configuration_path = File.join(vcap_bin, "../services", name, "config", "#{name}.yml")
    end
    @configuration_path
  end
end

class ServiceToolComponent < Component
  def service_tool?
    true
  end

  def get_path
    return @path if @path
    if name =~ /backup_manager|snapshot_manager/
      @path = File.join(vcap_bin, "../services", "tools", "backup", "manager", "bin", name)
    else
      @path = File.join(vcap_bin, "../services", "tools", name, "bin", name)
    end
    @path
  end

  def get_configuration_path
    @configuration_path ||= (File.join(configuration_file_in, "#{name}.yml") if configuration_file_in)
    unless @configuration_path && File.exist?(@configuration_path)
      if name =~ /backup_manager|snapshot_manager/
        @configuration_path = File.join(vcap_bin, "../services", "tools", "backup", "manager", "config", "#{name}.yml")
      else
        @configuration_path = File.join(vcap_bin, "../services", "tools", name, "config", "#{name}.yml")
      end
    end
    @configuration_path
  end
end

# register valid named components

## core
%w(router dea).each do |core|
   CoreComponent.register(core)
end
StagerComponent.register("stager")
ACMComponent.register("acm")
UAAComponent.register("uaa")
CCComponent.register("cloud_controller")
HMComponent.register("health_manager")

## standalone
%w(services_redis).each do |redis|
  ServicesRedisComponent.register(redis)
end

## services: gateways & nodes
%w(redis mysql mongodb rabbitmq postgresql vblob neo4j memcached couchdb elasticsearch filesystem echo).each do |service|
  ServiceComponent.register("#{service}_gateway")
end

%w(redis mysql mongodb rabbitmq postgresql vblob neo4j memcached couchdb elasticsearch echo).each do |service|
 ServiceComponent.register("#{service}_node")
end

%w(redis mysql mongodb postgresql).each do |service|
  ServiceComponent.register("#{service}_worker")
end

ServiceComponent.register("serialization_data_server")

## service auxiliary
%w(service_broker).each do |auxiliary|
 ServiceAuxiliaryComponent.register(auxiliary)
end

## service tools
%w(backup_manager snapshot_manager).each do |tool|
  ServiceToolComponent.register(tool)
end
