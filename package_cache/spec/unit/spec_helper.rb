require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))
def warden_is_alive?
  if File.exists? '/tmp/warden.sock'
    begin
      UNIXSocket.new('/tmp/warden.sock')
      return true
    rescue => e
    end
  end
  false
end


RSpec.configure do |c|
  # declare an exclusion filter
   unless warden_is_alive?
     c.filter_run_excluding :needs_warden => true
   end
end
