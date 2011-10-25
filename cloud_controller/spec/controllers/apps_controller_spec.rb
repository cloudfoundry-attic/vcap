require 'spec_helper'

describe AppsController do

  before :all do
    ActiveRecord::Base.lock_optimistically = false
  end

  describe '#update_app_env' do

    before :each do
      build_admin_and_user
      @app_name = 'example_app'
      @args = {'name' => @app_name, 'staging' => {'model' => 'sinatra', 'stack' => 'ruby18' }}
    end

    it 'should add the environment variable if its legal' do
      @args['env'] = ['foo=bar']
      headers_for(@user, nil, @args).each { |key, value| request.env[key] = value }
      post :create

      get :get, :name => @app_name
      Yajl::Parser.parse(response.body)['env'].should == ['foo=bar']

    end

    it 'should not add environment variables that start with vcap_' do
      @args['env'] =  ['vcap_foo=bar']
      headers_for(@user, nil, @args).each {|key, value| request.env[key] = value}
      post :create

      get :get, :name => @app_name
      Yajl::Parser.parse(response.body)['env'].should == []
    end

    it 'should not add environment variables that start with vmc_' do
      @args['env'] = ["vmc_foo=bar"]
      headers_for(@user, nil, @args).each {|key, value| request.env[key] = value }
      post :create

      get :get, :name => @app_name
      Yajl::Parser.parse(response.body)['env'].should == []
    end

    after :each do
      delete :delete, :name => @app_name
    end

  end

end
