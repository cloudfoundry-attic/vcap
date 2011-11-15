autoconfig = true
cf_config_file = File.expand_path("../config/cloudfoundry.yml", __FILE__)
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
$PROGRAM_NAME="./@@MAIN_FILE@@"
if autoconfig
  require 'cfautoconfig'
end
require File.join(File.dirname(__FILE__), '@@MAIN_FILE@@')
