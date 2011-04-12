require 'spec_helper'

describe "Specifying a proxy user" do
  before do
    User.admins = %w[a@example.com]
    @admin = User.new :email => 'a@example.com'
    @admin.set_and_encrypt_password 'password'
    @admin.save

    @user = User.new :email => 'user@example.com'
    @user.set_and_encrypt_password 'password'
    @user.save
  end

  describe "as an authorized admin" do
    it "performs the request as that user" do
      get cloud_info_url, nil, headers_for(@admin, @user)
      response.status.should == 200
      Yajl::Parser.parse(response.body)['user'].should == 'user@example.com'
    end
  end

  describe "as a regular user" do
    it "responds with a 403 status" do
      get cloud_info_url, nil, headers_for(@user, @admin)
      response.status.should == 403
    end
  end

  describe "as an anonymous badguy" do
    it "responds with a 403 status" do
      get cloud_info_url, nil, headers_for(nil, @user)
      response.status.should == 403
    end
  end
end
