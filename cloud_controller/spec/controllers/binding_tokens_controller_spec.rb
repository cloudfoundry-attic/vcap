require 'spec_helper'

describe BindingTokensController do
  before :each do
    u = User.new(:email => 'foo@bar.com')
    u.set_and_encrypt_password('foobar')
    u.save
    u.should be_valid
    @user = u

    ua = User.new(:email => 'bar@bar.com')
    ua.set_and_encrypt_password('foobar')
    ua.save
    ua.should be_valid
    @unauth_user = ua

    a = App.new(
      :owner => u,
      :name => 'foobar',
      :framework => 'sinatra',
      :runtime => 'ruby18'
    )
    a.save
    a.should be_valid
    @app = a

    svc = Service.new
    svc.label = "foo-bar"
    svc.url   = "http://localhost:56789"
    svc.token = 'foobar'
    svc.save
    svc.should be_valid
    @svc = svc

    cfg = ServiceConfig.new(:name => 'foo', :alias => 'bar', :service => @svc, :user => @user)
    cfg.save
    cfg.should be_valid
    @cfg = cfg

    tok = BindingToken.generate(
      :label => 'foo-bar',
      :binding_options => [],
      :service_config => cfg
    )
    tok.save
    tok.should be_valid
    @tok = tok

    request.env['CONTENT_TYPE'] = Mime::JSON
    request.env['HTTP_AUTHORIZATION'] = UserToken.create('foo@bar.com').encode
  end

  describe "Create binding token" do
    it 'should return not authorized for unknown users' do
      request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@foo.com').encode
      post :create
      (response.status == 403).should be_true
    end

    it 'should return not found for unknown configs' do
      post_msg :create do
        VCAP::Services::Api::BindingTokenRequest.new(
          :service_id => 'xxx',
          :binding_options => []
        )
      end
      (response.status == 404).should be_true
    end

    it 'should create binding tokens' do
      post_msg :create do
        VCAP::Services::Api::BindingTokenRequest.new(
          :service_id => 'foo',
          :binding_options => []
        )
      end
      (response.status == 200).should be_true
    end
  end

  describe "Fetch binding token" do
    it 'should return not found for unknown tokens' do
      get :get, :binding_token => 'xxx'
      (response.status == 404).should be_true
    end

    it 'should return binding tokens for valid requests' do
      get :get, :binding_token => @tok.uuid
      (response.status == 200).should be_true
    end
  end

  describe "Delete binding token" do
    it 'should return not found for unknown tokens' do
      delete :delete, :binding_token => 'xxx'
      (response.status == 404).should be_true
    end

    it 'should return forbidden if a user attempts to delete a binding token they did not create' do
      request.env['HTTP_AUTHORIZATION'] = UserToken.create('bar@bar.com').encode
      delete :delete, :binding_token => @tok.uuid
      (response.status == 403).should be_true
    end

    it 'should delete known binding tokens' do
      delete :delete, :binding_token => @tok.uuid
      (response.status == 200).should be_true
    end
  end

  def post_msg(*args, &blk)
    msg = yield
    request.env['RAW_POST_DATA'] = msg.encode
    post(*args)
  end

  def delete_msg(*args, &blk)
    msg = yield
    request.env['RAW_POST_DATA'] = msg.encode
    delete(*args)
  end

end
