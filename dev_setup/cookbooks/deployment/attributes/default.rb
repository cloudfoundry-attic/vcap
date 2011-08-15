default[:deployment][:name] = "devbox"
default[:deployment][:user] = ENV["USER"]
default[:deployment][:group] = "vcap"
default[:deployment][:home] = "#{File.join(ENV["HOME"], ".cloudfoundry", deployment[:name])}"
default[:deployment][:config_path] = "#{File.join(deployment[:home], "config")}"
default[:deployment][:info_file] = "#{File.join(deployment[:config_path], "deployment_info.json")}"
