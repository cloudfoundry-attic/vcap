#!/usr/bin/env ruby

require 'erb'
require 'json'
require 'tempfile'
require 'uri'
require 'pp'

script_dir = File.expand_path(File.dirname(__FILE__))
config_dir = File.expand_path(File.join(script_dir, "../env"))
vcap_dir = File.expand_path(File.join(script_dir, "../..")) 
cloudfoundry_home = ENV["CF_HOME"] || File.expand_path(File.join(ENV["HOME"], "cloudfoundry"))

`mkdir -p #{cloudfoundry_home}/deploy`
`mkdir -p #{cloudfoundry_home}/sys/log`

cloudfoundry_user = ENV["USER"]
cloudfoundry_group = `id -g`.strip

run_list = Array.new
run_list << "role[dea]"
run_list << "role[router]"
run_list << "role[cc]"

env_erb = ERB.new(File.read(File.join(config_dir, "dev_env.json.erb")))

# Find out the versions of the various packages
JSON.parse(env_erb.dup.result).each do |package, properties|
  case properties
  when Hash
    properties.each do |prop, value|
      if prop == "version"
        package_version = "@" + package + "_version"
        instance_variable_set(package_version.to_sym, value)
      end
    end
  end
end


# generate the chef-solo attributes
env = env_erb.result

# save the generated config file
File.open(File.join(config_dir, "dev_env.json"), "w") { |f|
  f.puts(env)
}

# Deploy all the cf components
Dir.mktmpdir { |tmpdir|
  # Create chef-solo config file
  File.open("#{tmpdir}/solo.rb", "w") { |f|
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
  }


  # Create chef-solo attributes file
  json_attribs = "#{tmpdir}/solo.json"
  File.open(json_attribs, "w") { |f|
    f.puts(env)
  }

  FileUtils.cp("#{tmpdir}/solo.rb", "/tmp/solo.rb")
  FileUtils.cp("#{json_attribs}", "/tmp/solo.json")

  id = fork {
    proxy_env = Array.new
    proxy_env << "http_proxy=#{ENV["http_proxy"]}" unless ENV["http_proxy"].nil? 
    proxy_env << "https_proxy=#{ENV["https_proxy"]}" unless ENV["https_proxy"].nil? 
    proxy_env << "no_proxy=#{ENV["no_proxy"]}" unless ENV["no_proxy"].nil? 
    exec("sudo env #{proxy_env.join(" ")} chef-solo -c #{tmpdir}/solo.rb -j #{json_attribs} -l debug")
  }
  pid, status = Process.waitpid2(id)
  exit status.exitstatus if status.exitstatus != 0
}

# Run bundler:install in cf home dir
def exec_cmd(cmd)
  id = fork {
    puts "Executing #{cmd}"
    exec(cmd)
  }
  pid, status = Process.waitpid2(id)
  status.exitstatus
end

env = JSON.parse(env)
ruby_path = "#{env["ruby"]["path"]}/bin"
gemdir = `#{ruby_path}/gem environment gemdir`.split("\n")[0]
ENV["PATH"] = "#{ruby_path}:#{gemdir}/bin:#{ENV["PATH"]}"
status = exec_cmd("cd #{vcap_dir}; rake bundler:install; gem install vmc --no-rdoc --no-ri -q")
if status == 0
  puts "Cloudfoundry setup was successful."
  puts "Note: You may need to add #{ruby_path} to your path to use vmc"
end
