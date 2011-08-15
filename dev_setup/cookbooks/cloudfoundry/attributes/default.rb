include_attribute "deployment"
default[:cloudfoundry][:repo] = "https://github.com/cloudfoundry/vcap.git"
default[:cloudfoundry][:path] = "#{node[:deployment][:home]}/vcap"
default[:cloudfoundry][:revision] = "HEAD"
default[:cloudfoundry][:download] = true
