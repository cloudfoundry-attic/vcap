autoconfig = true
begin
    config = File.open(File.join(RAILS_ROOT,'config','cloudfoundry.yml')) do |f|
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
  require 'cfautoconfig'
end
