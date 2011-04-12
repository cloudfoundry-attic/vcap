require 'spec_helper'

describe "Requesting a new user token" do
  before do
    build_admin_and_user
    @email = 'admin@example.com'
  end

  it "returns a 400 response when given invalid JSON" do
    bad_data = '{{{}}}'
    post create_token_path('email' => @email), nil, headers_for(@email, nil, bad_data)
    response.status.should == 400
  end
end
