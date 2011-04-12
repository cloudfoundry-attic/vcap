require 'spec_helper'

describe BindingToken do
  it "requires a label" do
    bt = BindingToken.generate
    bt.should have_at_least(1).errors_on(:label)
  end

  it "should generate valid tokens" do
    bt = BindingToken.generate(:label => "foo-bar", :binding_options => [], :service_config_id => 1)
    bt.should be_valid
  end
end
