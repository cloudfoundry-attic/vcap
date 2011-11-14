autoconfig = true
begin
    config = File.open(File.join(File.dirname(__FILE__), 'config','cloudfoundry.yml')) do |f|
       YAML.load(f)
    end
    if !config['autoconfig'].nil? && !config['autoconfig']
       puts "Application requested to skip auto-reconfiguration"
       autoconfig = false
    end
rescue => e
    puts "No 'config/cloudfoundry.yml' found.  Auto-reconfiguration is active."
end
if autoconfig
   $PROGRAM_NAME="@@MAIN_FILE@@"
   require 'cfautoconfig/stager'
end
require File.join(File.dirname(__FILE__), '@@MAIN_FILE@@')
