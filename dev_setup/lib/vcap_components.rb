# Copyright (c) 2009-2011 VMware, Inc.
#

require 'yaml'
require 'fileutils'

require File.expand_path("./vcap_common.rb", File.dirname(__FILE__))

class Component
  @@named_components = {}
  @@excluded = []

  DEFAULT_CLOUD_FOUNDRY_EXCLUDED_COMPONENT = 'neo4j|memcached|couchdb|service_broker|elasticsearch|backup_manager|echo'

  attr :name

  def self.create(name, configuration_file=nil)
    sub_class = @@named_components[name]
    if sub_class
      sub_class.new(name, configuration_file)
    else
      nil
    end
  end

  def self.register(name, excluded=nil)
    @@named_components[name] = self
    default_excluded=/#{DEFAULT_CLOUD_FOUNDRY_EXCLUDED_COMPONENT}/
    if excluded == true || (excluded.nil? && name =~ default_excluded)
      @@excluded << name
    end
  end

  def self.getNamedComponents()
    @@named_components
  end

  def self.getExcludedComponents()
    @@excluded
  end

  private
  def initialize(name, configuration_file = nil)
    @name = name
    @configuration_path = configuration_file || get_configuration_path
  end

  public
  def is_cloud_controller?
    @name =~ /cloud_controller/i
  end

  def is_router?
    @name =~ /router/i
  end

  def to_s
    name
  end

  def is_excluded?
    excluded_env = $excluded || ENV['CLOUD_FOUNDRY_EXCLUDED_COMPONENT']
    unless excluded_env.nil?
      if excluded_env.empty?
        false
      else
        name.match(excluded_env)
      end
    else
      @@excluded.include?(name)
    end
  end

  def exists?
    File.exists? get_path
  end

  def vcap_bin
    DIR
  end

  def get_path
    @path = File.join(vcap_bin, name)
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
          cc_dir = File.expand_path(File.join(vcap_bin, '..', 'cloud_controller'))
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
    puts "#{name.ljust(20)}:\t #{status}"
  end

end

class CoreComponent < Component
  def core?
    true
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

  def get_path
    return @path if @path
    pre = name.sub(/_node|_gateway/,'')
    # mapping 'rabbitmq' in dev_setup to 'rabbit' in services
    pre = 'rabbit' if pre == 'rabbitmq'
    bin_name = name.index('rabbitmq')? name.sub(/mq/, '') : name
    @path = File.join(vcap_bin, "../services", pre, "bin", bin_name)
  end

  def get_configuration_path
    @configuration_path ||= (File.join(configuration_file_in, "#{name}.yml") if configuration_file_in)
    unless @configuration_path && File.exist?(@configuration_path)
      pre = name.sub(/_node|_gateway/,'')
      # mapping 'rabbitmq' in dev_setup to 'rabbit' in services
      pre = 'rabbit' if pre == 'rabbitmq'
      @configuration_path = File.join(vcap_bin, "../services", pre, "config", "#{name}.yml")
    end
    @configuration_path
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
%w(router cloud_controller dea health_manager uaa acm).each do |core|
   CoreComponent.register(core)
end

## services: gateways & nodes
%w(redis mysql mongodb rabbitmq postgresql vblob neo4j memcached couchdb elasticsearch filesystem echo).each do |service|
  ServiceComponent.register("#{service}_gateway")
end

%w(redis mysql mongodb rabbitmq postgresql vblob neo4j memcached couchdb elasticsearch echo).each do |service|
 ServiceComponent.register("#{service}_node")
end

## service auxiliary
%w(service_broker).each do |auxiliary|
 ServiceAuxiliaryComponent.register(auxiliary)
end

## service tools
%w(backup_manager snapshot_manager).each do |tool|
  ServiceToolComponent.register(tool)
end
