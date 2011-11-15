autoconfig = true
cf_config_file = RAILS_ROOT + '/config/cloudfoundry.yml'
if File.exists? cf_config_file
  config = File.open(cf_config_file) do |f|
    YAML.load(f)
  end
  if config['autoconfig'] == false
    puts "Application requested to skip auto-reconfiguration"
    autoconfig = false
  end
else
  puts "No 'config/cloudfoundry.yml' found.  Auto-reconfiguration is active."
end
if autoconfig
  require 'cfautoconfig'
end
