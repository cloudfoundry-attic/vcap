#!/usr/bin/env ruby
require 'rubygems'
require 'erb'
require 'json'
require 'tempfile'
require 'uri'
require 'fileutils'
require 'yaml'
require 'pp'

$LOAD_PATH.unshift(File.dirname(__FILE__))

require File.expand_path('vcap_defs', File.dirname(__FILE__))
require File.expand_path('job_manager', File.dirname(__FILE__))

script_dir = File.expand_path(File.dirname(__FILE__))
deployment_spec = File.expand_path(File.join(script_dir, "..", DEPLOYMENT_DEFAULT_SPEC))
deployment_name = DEPLOYMENT_DEFAULT_NAME
deployment_home = Deployment.get_home(deployment_name)
deployment_user = ENV["USER"]
deployment_group = `id -g`.strip

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
  when "deployment"
    deployment_name = properties["name"] || deployment_name
    deployment_home = properties["home"] || Deployment.get_home(deployment_name)
    deployment_user = properties["user"] || deployment_user
    deployment_group = properties["group"] || deployment_group
  end
end
deployment_config_path = Deployment.get_config_path(deployment_home)

puts "Installing deployment #{deployment_name}, deployment home dir is #{deployment_home}"

# Fill in default config attributes
spec = YAML.load(spec_erb.result)
spec["deployment"] ||= {}
spec["deployment"]["name"] = deployment_name
spec["deployment"]["home"] = deployment_home
spec["deployment"]["user"] = deployment_user
spec["deployment"]["group"] = deployment_group
spec["deployment"]["config_path"] = deployment_config_path

# Resolve all job dependencies
vcap_run_list = {}
job_specs, job_roles, vcap_run_list["components"] = JobManager.go(spec)
if job_roles.nil?
  puts "You haven't specified any install jobs"
  exit 0
end

# Prepare the chef run list
run_list = []
job_roles.each do |role|
  run_list << "role[#{role}]"
end
spec["run_list"] = run_list

# Merge the job specs
spec.merge!(job_specs)

# Deploy
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

  # Save the chef-solo attributes to a file in /tmp, useful for debugging
  File.open(File.join("", "tmp", "solo.json"), "w") { |f| f.puts(spec.to_json) }

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
  File.open(Deployment.get_config_file(deployment_config_path), "w") { |f| f.puts(spec.to_json) }

  # save the list of components that should be started for this deployment
  File.open(Deployment.get_vcap_config_file(deployment_config_path), "w") { |f| f.puts(vcap_run_list.to_json) }

  puts "---------------"
  puts "Deployment info"
  puts "---------------"
  puts "Status: successful"

  vcap_dev_path = File.expand_path(File.join(script_dir, "..", "bin", "vcap_dev"))
  if deployment_name != DEPLOYMENT_DEFAULT_NAME
    puts "Config files: #{deployment_config_path}"
    puts "Deployment name: #{deployment_name}"
    puts "Command to run cloudfoundry: #{vcap_dev_path} -d #{deployment_name} start"
  else
    puts "Command to run Cloudfoundry: #{vcap_dev_path} start"
  end
end
