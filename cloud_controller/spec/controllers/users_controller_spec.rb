require 'spec_helper'

describe UsersController do
  before :each do
    build_admin_and_user
    @user_headers = headers_for(@user.email, nil)
    @admin_headers = headers_for(@admin.email, nil)
    request.env["HTTP_AUTHORIZATION"] = ""
  end

  describe "#list" do
    it 'should return 200 as an admin' do
      @admin.admin?.should be_true
      @admin_headers.each {|key, value| request.env[key] = value}
      get :list
      response.status.should == 200
      json = Yajl::Parser.parse(response.body)
      json.should be_kind_of(Array)
      json.count.should >= 2
    end

    it 'should return 403 as a user' do
      @user_headers.each {|key, value| request.env[key] = value}
      get :list
      response.status.should == 403
    end

    it 'should return 403 without authentication' do
      get :list
      response.status.should == 403
    end
  end

  describe "#delete" do
    it 'should return 204 as an admin' do
      @admin.admin?.should be_true
      @admin_headers.each {|key, value| request.env[key] = value}
      delete :delete, {:email => @user.email}
      response.status.should == 204
      User.find_by_email(@user.email).should be_nil
      User.find_by_email(@admin.email).should_not be_nil
    end

    it 'should return 403 as a user' do
      @user_headers.each {|key, value| request.env[key] = value}
      delete :delete, {:email => @user.email}
      response.status.should == 403
      User.find_by_email(@user.email).should_not be_nil
    end

    it 'should return 403 without authentication' do
      delete :delete, {:email => @user.email}
      response.status.should == 403
      User.find_by_email(@user.email).should_not be_nil
    end
  end
end
