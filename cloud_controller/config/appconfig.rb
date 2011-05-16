# If any of the required options are missing, the AppConfig[:defaulted] key is set.
# Once we know which Rails environment we are in, we can fail fast in production
# mode by checking that flag. This code runs too early to know for sure if
# we are starting in production mode.

require 'vcap/common'

config_file = ENV['CLOUD_CONTROLLER_CONFIG'] || File.expand_path('../cloud_controller.yml', __FILE__)
begin
  if File.exists?(config_file)
    config = YAML.load_file(config_file)
    if Hash === config
      AppConfig = VCAP.symbolize_keys(config)
    else
      AppConfig = nil
    end
  end
rescue => ex
  $stderr.puts %[FATAL: Exception encountered while loading config file: #{ex}\n#{ex.backtrace.join("\n")}]
  exit 1
end

unless AppConfig
  $stderr.puts %[FATAL: Unable to load specified config file from: #{config_file}]
  exit 1
end

env_overrides = {:local_route => 'CLOUD_CONTROLLER_HOST',
                 :instance_port => 'CLOUD_CONTROLLER_PORT',
                 :rails_environment => 'RAILS_ENV'}

required = { :external_uri => 'api.vcap.me',
             :rails_environment => 'development',
             :local_route  => '127.0.0.1',
             :local_register_only => true,
             :allow_external_app_uris => false,
             :staging => { :max_concurrent_stagers => 10,
                           :max_staging_runtime => 60 },
             :instance_port => 9022,
             :directories => { :droplets          => '/var/vcap/shared/droplets',
                               :resources         => '/var/vcap/shared/resources',
                               :staging_manifests => 'staging/manifests',
                               :staging_cache     => '/var/vcap.local/staging',
                               :tmpdir            => 'tmp'},
             :mbus => 'nats://localhost:4222/',
             :log_level => 'DEBUG',
             :keys => { :password => 'da39a3ee5e6b4b0d3255bfef95601890afd80709', :token => 'default_key'},
             :pid => '/var/vcap/sys/run/cloudcontroller.pid',
             :admins => [],
             :default_account_capacity => { :memory => 2048,
                                            :app_uris => 4,
                                            :services => 16,
                                            :apps => 20 } }

# Does the given hash have at least the keys contained in the default?
required_keys = Proc.new do |candidate, default|
  Hash === candidate && default.keys.all? {|k| candidate.key?(k)}
end

defaulted_on = Proc.new do |config_key|
  AppConfig[:defaulted] ||= [] # Used to throw a startup error in production mode.
  AppConfig[:defaulted].push(config_key)
end

required.each do |config_key, default|
  if AppConfig.key?(config_key)
    current = AppConfig[config_key]
    if Hash === default
      if required_keys.call(current, default)
        next
      else
        defaulted_on.call(config_key)
        AppConfig[config_key] = default.merge(current)
      end
    end
  else
    defaulted_on.call(config_key)
    AppConfig[config_key] = default
  end
end

# Certain options have environment variable overrides for use in startup scripts.
env_overrides.each do |cfg_key, env_key|
  if ENV.key?(env_key)
    AppConfig[cfg_key] = ENV[env_key]
  end
end

# Check on new style app_uris and map old into new style.
unless AppConfig.key? :app_uris
  AppConfig[:app_uris] = {
    :allow_external => AppConfig[:allow_external_app_uris],
  }
end

AppConfig[:app_uris][:reserved_list] ||= []

unless AppConfig[:app_uris][:reserved_file].nil?
  # Make sure we can load it in
  reserved_from_file = nil
  begin
    reserved_from_file = File.read(AppConfig[:app_uris][:reserved_file]).split("\n")
  rescue => ex
    $stderr.puts %[FATAL: Exception encountered while loading reserved urls: #{ex}\n#{ex.backtrace.join("\n")}]
    exit 1
  end

  AppConfig[:app_uris][:reserved_list].concat(reserved_from_file)
end

# Normalize directories
root = File.expand_path('../..', __FILE__)
AppConfig[:directories].each do |type, path|
  next if path[0,1] == '/'
  AppConfig[:directories][type] = File.expand_path(File.join(root, path))
end

# Config for builtin services that don't need to be pre-registered
if AppConfig[:builtin_services]
  unless AppConfig[:builtin_services].kind_of? Hash
    klass = AppConfig[:builtin_services].class
    $stderr.puts "FATAL: Builtin service config is invalid. Expected Hash, got #{klass}."
    exit 1
  end

  errs = {}
  AppConfig[:builtin_services].each do |vendor, info|
    unless info.has_key? :token
      errs[vendor] = "Missing token key"
      next
    end

    unless (info[:token].kind_of? String) || (info[:token].kind_of? Integer)
      errs[vendor] = "Token must be a string or integer, #{info[:token].class} given."
      next
    end

    info[:token] = info[:token].to_s
  end

  unless errs.empty?
    errstr = errs.map {|vendor, err| "#{vendor} : #{err}"}.join(", ")
    $stderr.puts "There were errors with the following builtin services: #{errstr}"
    exit 1
  end
end

c = OpenSSL::Cipher::Cipher.new('blowfish')
pw_len = AppConfig[:keys][:password].length
if pw_len < c.key_len
  $stderr.puts "The supplied password is too short (#{pw_len} bytes), must be at least #{c.key_len} bytes. (Though only the first #{c.key_len} will be used.)"
  exit 1
end
