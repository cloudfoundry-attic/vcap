include_recipe "deployment"
include_attribute "postgresql"
include_attributes "uaa"
include_attributes "service_lifecycle"

default[:deployment][:welcome] = "VMware's Cloud Application Platform"

default[:cloud_controller][:config_file] = "cloud_controller.yml"
default[:cloud_controller][:service_api_uri] = "http://api.#{node[:deployment][:domain]}"
default[:cloud_controller][:local_route] = nil
default[:cloud_controller][:admins] = ["dev@cloudfoundry.org"]
default[:cloud_controller][:runtimes_file] = "runtimes.yml"

# Default builtin services
default[:cloud_controller][:builtin_services] = ["redis", "mongodb", "mysql", "neo4j", "rabbitmq", "postgresql", "vblob", "memcached", "filesystem", "elasticsearch", "couchdb", "echo"]

# Default capacity
default[:capacity][:max_uris] = 4
default[:capacity][:max_services] = 16
default[:capacity][:max_apps] = 20
