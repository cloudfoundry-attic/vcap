#!/usr/bin/env ruby

require 'erb'
require 'json'
require 'tempfile'
require 'uri'
require 'fileutils'
require 'pp'
require File.expand_path('vcap_defs', File.dirname(__FILE__))

script_dir = File.expand_path(File.dirname(__FILE__))
vcap_dir = File.expand_path(File.join(script_dir, "../.."))
deployment_config = File.expand_path(File.join(script_dir, "..", DEFAULT_DEPLOYMENT_CONFIG))
deployment_home = DEFAULT_DEPLOYMENT_HOME
deployment_name = DEFAULT_DEPLOYMENT_NAME
deployment_user = ENV["USER"]
deployment_group = `id -g`.strip
download_cloudfoundry = false

unless ARGV[0].nil?
  deployment_config = ARGV[0]
  unless File.exists?(deployment_config)
    puts "Cannont find deployment config file #{deployment_config}"
    exit 1
  end
end

env_erb = ERB.new(File.read(deployment_config))

JSON.parse(env_erb.dup.result).each do |package, properties|
  # Find out the versions of the various packages
  case properties
  when Hash
    properties.each do |prop, value|
      if prop == "version"
        package_version = "@" + package + "_version"
        instance_variable_set(package_version.to_sym, value)
      end
    end
  end

  # Update config defaults
  case package
  when "cloudfoundry"
    vcap_dir = File.expand_path(properties["path"])
    download_cloudfoundry = true
    puts "vcap_dir is now #{vcap_dir}"
  when "deployment_name"
    deployment_name = properties
  when "deployment_home"
    deployment_home=properties
  when "deployment_user"
    deployment_user = properties
  when "deployment_group"
    deployment_group = properties
  end
end

`mkdir -p #{deployment_home}/deploy;`
`mkdir -p #{deployment_home}/sys/log`
`chown #{deployment_user} #{deployment_home} #{deployment_home}/deploy #{deployment_home}/sys/log`
puts "Installing deployment #{deployment_name}, deployment home dir is #{deployment_home}, vcap dir is #{vcap_dir}"

run_list = []
run_list << "role[dea]"
run_list << "role[router]"
run_list << "role[cc]"
run_list << "role[cloudfoundry]" if download_cloudfoundry

# generate the chef-solo attributes
env = env_erb.result

# Deploy all the cf components
Dir.mktmpdir do |tmpdir|
  # Create chef-solo config file
  File.open("#{tmpdir}/solo.rb", "w") do |f|
    f.puts("cookbook_path \"#{File.expand_path("../cookbooks", script_dir)}\"")
    f.puts("role_path \"#{File.expand_path("../roles", script_dir)}\"")

    %w[ http_proxy https_proxy].each do |proxy|
      unless ENV[proxy].nil?
          uri = URI.parse(ENV[proxy])
          f.puts("#{proxy} \"#{uri.scheme}://#{uri.host}:#{uri.port}\"")
          unless uri.userinfo.nil?
            f.puts("http_proxy_user \"#{uri.userinfo.split(":")[0]}\"")
            f.puts("http_proxy_pass \"#{uri.userinfo.split(":")[1]}\"")
          end
      end
    end
    unless ENV["no_proxy"].nil?
        f.puts("no_proxy \"#{ENV["no_proxy"]}\"")
    end
  end

  # Create chef-solo attributes file
  json_attribs = "#{tmpdir}/solo.json"
  File.open(json_attribs, "w") {|f| f.puts(env)}

  FileUtils.cp("#{tmpdir}/solo.rb", "/tmp/solo.rb")
  FileUtils.cp("#{json_attribs}", "/tmp/solo.json")

  id = fork do
    proxy_env = []
    # Setup proxy
    %w(http_proxy https_proxy no_proxy).each do |env_var|
      if  !ENV[env_var].nil? || !ENV[env_var.upcase].nil?
        [env_var, env_var.upcase].each do |v|
          proxy = "#{v}=#{ENV[v.downcase] || ENV[v.upcase]}"
          proxy_env << proxy
        end
      end
    end
    exec("sudo env #{proxy_env.join(" ")} chef-solo -c #{tmpdir}/solo.rb -j #{json_attribs} -l debug")
  end

  pid, status = Process.waitpid2(id)
  if status.exitstatus != 0
    exit status.exitstatus
  end

  # save the config of this deployment
  config_base_dir = File.expand_path(File.join(vcap_dir, CONFIG_BASE_DIR))
  FileUtils.mkdir_p(config_base_dir)
  `chown #{deployment_user} #{config_base_dir}`

  config_dir = File.join(config_base_dir, deployment_name)
  FileUtils.mkdir_p(config_dir)
  `chown #{deployment_user} #{config_dir}`

  File.open(File.join(config_dir, DEPLOYMENT_FILE), "w") { |f|
    f.puts(env)
  }

  puts "Cloudfoundry setup was successful."
  if deployment_name != DEFAULT_DEPLOYMENT_NAME
    puts "Config file for this deployment is in #{config_dir}."
  end

  env = JSON.parse(env)
  ruby_path = "#{env["ruby"]["path"]}/bin"
  puts "Note: You may need to add #{ruby_path} to your path to use vmc"
end
