default[:cloudfoundry][:home] = File.join(ENV["HOME"], "cloudfoundry")
default[:cloudfoundry][:path] = "#{cloudfoundry[:home]}/vcap"
