include_recipe "deployment"
default[:cloud_controller][:config_file] = "cloud_controller.yml"
default[:cloud_controller][:service_api_uri] = "http://api.#{node[:deployment][:domain]}"
default[:cloud_controller][:local_route] = nil

# Staging
default[:cloud_controller][:staging][:grails] = "grails.yml"
default[:cloud_controller][:staging][:lift] = "lift.yml"
default[:cloud_controller][:staging][:node] = "node.yml"
default[:cloud_controller][:staging][:otp_rebar] = "otp_rebar.yml"
default[:cloud_controller][:staging][:platform] = "platform.yml"
default[:cloud_controller][:staging][:rails3] = "rails3.yml"
default[:cloud_controller][:staging][:sinatra] = "sinatra.yml"
default[:cloud_controller][:staging][:spring] = "spring.yml"

# Default builtin services
default[:cloud_controller][:builtin_services] = ["redis", "mongodb", "mysql"]
