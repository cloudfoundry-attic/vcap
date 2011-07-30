default[:service][:mysql][:token] = "#{rand(36**36).to_s(36)}"
default[:service][:mongodb][:token] = "#{rand(36**36).to_s(36)}"
default[:service][:postgresql][:token] = "#{rand(36**36).to_s(36)}"
default[:service][:redis][:token] = "#{rand(36**36).to_s(36)}"
