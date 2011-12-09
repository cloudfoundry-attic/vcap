require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

RSpec.configure do |c|
  if Process.uid != 0
    c.filter_run_excluding :needs_root => true
  end
end

