include_attribute "deployment"

default[:filesystem][:supported_versions] = {
        "1.0" => "1.0",
}
default[:filesystem][:version_aliases] = {
        "current" => "1.0",
}
default[:filesystem][:default_version] = "1.0"

default[:filesystem_node][:token] = "changefilesystemtoken"

default[:filesystem_gateway][:service][:timeout] = "15"
default[:filesystem_gateway][:node_timeout] = "10"
default[:filesystem_gateway][:backends] = ["/var/vcap/store/fss_backend1"]
