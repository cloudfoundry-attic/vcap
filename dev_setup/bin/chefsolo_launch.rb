#!/usr/bin/env ruby

require 'erb'
require 'json'
require 'tempfile'
require 'uri'
require 'fileutils'
require 'yaml'
require 'pp'
require File.expand_path('vcap_defs', File.dirname(__FILE__))

script_dir = File.expand_path(File.dirname(__FILE__))
vcap_path = File.expand_path(File.join(script_dir, "..", ".."))
deployment_spec = File.expand_path(File.join(script_dir, "..", DEPLOYMENT_DEFAULT_SPEC))
deployment_name = DEPLOYMENT_DEFAULT_NAME
deployment_home = Deployment.get_home(deployment_name)
deployment_user = ENV["USER"]
deployment_group = `id -g`.strip
download_cloudfoundry = false

deployment_spec = ARGV[0] if ARGV[0]

unless File.exists?(deployment_spec)
  puts "Cannot find deployment spec #{deployment_spec}"
  puts "Usage: #{$0} [deployment_spec]"
  exit 1
end

spec_erb = ERB.new(File.read(deployment_spec))

YAML.load(spec_erb.result).each do |package, properties|
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
    vcap_path = File.expand_path(properties["path"])
    download_cloudfoundry = true unless properties["revision"].nil?
    puts "vcap_path is now #{vcap_path}"
  when "deployment"
    deployment_name = properties["name"] || deployment_name
    deployment_home = properties["home"] || deployment_home
    deployment_user = properties["user"] || deployment_user
    deployment_group = properties["group"] || deployment_group
  end
end
deployment_config_path = Deployment.get_config_path(deployment_home)

FileUtils.mkdir_p(File.join(deployment_home, "deploy"))
FileUtils.mkdir_p(File.join(deployment_home, "sys", "log"))
FileUtils.chown(deployment_user, deployment_group, [deployment_home, File.join(deployment_home, "deploy"), File.join(deployment_home, "sys", "log")])
puts "Installing deployment #{deployment_name}, deployment home dir is #{deployment_home}, vcap dir is #{vcap_path}"

run_list = []
run_list << "role[cloudfoundry]" if download_cloudfoundry
run_list << "role[router]"
run_list << "role[cloud_controller]"
run_list << "role[dea]"
run_list << "recipe[health_manager]"
run_list << "recipe[services]"

# Fill in default config attributes
spec = YAML.load(spec_erb.result)
spec["run_list"] = run_list
spec["deployment"] ||= {}
spec["deployment"]["name"] = deployment_name
spec["deployment"]["home"] = deployment_home
spec["deployment"]["user"] = deployment_user
spec["deployment"]["group"] = deployment_group
spec["deployment"]["config_path"] = deployment_config_path
spec["cloudfoundry"] ||= {}
spec["cloudfoundry"]["path"] = vcap_path

# Deploy all the cf components
Dir.mktmpdir do |tmpdir|
  # Create chef-solo config file
  File.open(File.join(tmpdir, "solo.rb"), "w") do |f|
    f.puts("cookbook_path \"#{File.expand_path(File.join("..", "cookbooks"), script_dir)}\"")
    f.puts("role_path \"#{File.expand_path(File.join("..", "roles"), script_dir)}\"")

    %w[ http_proxy https_proxy].each do |proxy|
      if ENV[proxy]
        uri = URI.parse(ENV[proxy])
        f.puts("#{proxy} \"#{uri.scheme}://#{uri.host}:#{uri.port}\"")
        if uri.userinfo
          f.puts("http_proxy_user \"#{uri.userinfo.split(":")[0]}\"")
          f.puts("http_proxy_pass \"#{uri.userinfo.split(":")[1]}\"")
        end
      end
    end
    if ENV["no_proxy"]
      f.puts("no_proxy \"#{ENV["no_proxy"]}\"")
    end
  end

  # Create chef-solo attributes file
  json_attribs = File.join(tmpdir, "solo.json")
  File.open(json_attribs, "w") { |f| f.puts(spec.to_json) }

  id = fork do
    proxy_env = []
    # Setup proxy
    %w(http_proxy https_proxy no_proxy).each do |env_var|
      if ENV[env_var] || ENV[env_var.upcase]
        [env_var, env_var.upcase].each do |v|
          proxy = "#{v}=#{ENV[v.downcase] || ENV[v.upcase]}"
          proxy_env << proxy
        end
      end
    end
    exec("sudo env #{proxy_env.join(" ")} chef-solo -c #{File.join(tmpdir, "solo.rb")} -j #{json_attribs} -l debug")
  end

  pid, status = Process.waitpid2(id)
  if status.exitstatus != 0
    exit status.exitstatus
  end

  # save the config of this deployment
  FileUtils.mkdir_p(deployment_config_path)
  FileUtils.chown(deployment_user, deployment_group, deployment_config_path)

  File.open(Deployment.get_config_file(deployment_config_path), "w") { |f| f.puts(spec.to_json) }

  puts "Cloudfoundry setup was successful."
  if deployment_name != DEPLOYMENT_DEFAULT_NAME
    puts "Config file for this deployment is in #{deployment_config_path}."
  end

  ruby_path = File.join(spec["ruby"]["path"], "bin")
  puts "Note: You may need to add #{ruby_path} to your path to use vmc"
end
