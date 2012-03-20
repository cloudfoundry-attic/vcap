include_recipe "deployment"
default[:deployment][:welcome] = "VMware's Cloud Application Platform"

default[:cloud_controller][:config_file] = "cloud_controller.yml"
default[:cloud_controller][:service_api_uri] = "http://api.#{node[:deployment][:domain]}"
default[:cloud_controller][:local_route] = nil
default[:cloud_controller][:admins] = ["dev@cloudfoundry.org"]
default[:cloud_controller][:bootstrap_users] = []
default[:cloud_controller][:allow_registration] = "true"

# Staging
default[:cloud_controller][:staging][:grails] = "grails.yml"
default[:cloud_controller][:staging][:lift] = "lift.yml"
default[:cloud_controller][:staging][:node] = "node.yml"
default[:cloud_controller][:staging][:otp_rebar] = "otp_rebar.yml"
default[:cloud_controller][:staging][:platform] = "platform.yml"
default[:cloud_controller][:staging][:rails3] = "rails3.yml"
default[:cloud_controller][:staging][:sinatra] = "sinatra.yml"
default[:cloud_controller][:staging][:spring] = "spring.yml"
default[:cloud_controller][:staging][:java_web] = "java_web.yml"
default[:cloud_controller][:staging][:php] = "php.yml"
default[:cloud_controller][:staging][:dotNet] = "dotNet.yml"

# Default builtin services
default[:cloud_controller][:builtin_services] = ["redis", "mongodb", "mysql", "neo4j", "mssql"]

# Default capacity
default[:capacity][:max_uris] = 4
default[:capacity][:max_services] = 16
default[:capacity][:max_apps] = 20
default[:capacity][:max_memory] = 2048