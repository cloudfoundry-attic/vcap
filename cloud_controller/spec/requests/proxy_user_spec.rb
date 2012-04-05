require 'spec_helper'

describe "Specifying a proxy user" do

  before do
    build_admin_and_user
  end

  shared_examples_for "any request to test a proxy user" do
    describe "as an authorized admin" do
      it "performs the request as that user" do
        get cloud_info_url, nil, headers_for(@admin, @user)
        response.status.should == 200
        Yajl::Parser.parse(response.body)['user'].should == @user.email
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

  context "using conventional tokens" do
    it_should_behave_like "any request to test a proxy user"
  end

  context "using jwt tokens" do
    before :all do
      CloudSpecHelpers.use_jwt_token = true
    end

    it_should_behave_like "any request to test a proxy user"
  end

end
