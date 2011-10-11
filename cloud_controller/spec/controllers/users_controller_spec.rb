require 'spec_helper'

describe UsersController do
  before :each do
    build_admin_and_user
    @user_headers = headers_for(@user.email, nil)
    @admin_headers = headers_for(@admin.email, nil)
    request.env["HTTP_AUTHORIZATION"] = ""
  end

  describe '#create' do
    it 'should return 403 if the user is not an admin and registration is disabled' do
      AppConfig[:allow_registration] = false
      post_with_body :create do
        { :email    => 'foo@bar.com',
          :password => 'testpass',
        }
      end
      response.status.should == 403
    end

    it 'should create users if the user is an admin and registration is disabled' do
      AppConfig[:allow_registration] = false
      User.find_by_email('foo@bar.com').should be_nil
      @admin.admin?.should be_true
      @admin_headers.each {|key, value| request.env[key] = value}
      post_with_body :create do
        { :email    => 'foo@bar.com',
          :password => 'testpass',
        }
      end
      response.status.should == 204
      User.find_by_email('foo@bar.com').should_not be_nil
    end

    it 'should create users if the user is not an admin and registration is allowed' do
      AppConfig[:allow_registration] = true
      User.find_by_email('foo@bar.com').should be_nil
      post_with_body :create do
        { :email    => 'foo@bar.com',
          :password => 'testpass',
        }
      end
      response.status.should == 204
      User.find_by_email('foo@bar.com').should_not be_nil
    end
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

  def post_with_body(*args, &blk)
    body = yield
    request.env['RAW_POST_DATA'] = Yajl::Encoder.encode(body)
    post(*args)
  end
end
