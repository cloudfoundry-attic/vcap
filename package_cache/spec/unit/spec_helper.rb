require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

RSpec.configure do |c|
  if `sudo whoami`.chop != 'root'
    c.filter_run_excluding :needs_sudo => true
  end
end

