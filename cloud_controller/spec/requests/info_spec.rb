require 'spec_helper'

describe "A GET request to /info" do
  it "as an anonymous user" do
    get cloud_info_url
    response.status.should == 200
  end

  describe "with a user header" do
    before do
      @user ||= begin
                  u = User.new(:email => 'user@example.com')
                  u.set_and_encrypt_password('password')
                  u.save!
                  u
                end
    end

    it "that is valid" do
      get cloud_info_url, nil, headers_for(@user)
      response.status.should == 200
      json = Yajl::Parser.parse(response.body)
      json.should have_key('user')
    end

    it "that is invalid" do
      headers = headers_for(@user)
      headers['HTTP_AUTHORIZATION'].reverse!
      get cloud_info_url, nil, headers
      response.status.should == 200
      json = Yajl::Parser.parse(response.body)
      json.should_not have_key('user')
    end
  end
end

