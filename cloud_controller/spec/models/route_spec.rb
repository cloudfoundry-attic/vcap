require 'spec_helper'

describe Route do
  before do
    AppConfig[:external_uri] = 'api.cloudfoundry.com'

    @user1 = build_user('route1@example.com')
    @user2 = build_user('route2@example.com')

    @user1.save!
    @user2.save!

    # user1 owns app1 and app2, user2 is trying to create app3
    @app1 = App.new(:name => 'app1', :owner => @user1, :framework => 'node', :runtime => 'node')
    @app2 = App.new(:name => 'app2', :owner => @user1, :framework => 'node', :runtime => 'node')
    @app3 = App.new(:name => 'app3', :owner => @user2, :framework => 'node', :runtime => 'node')

    @app1.save!
    @app2.save!
    @app3.save!
  end

  it "is valid if the url is already used by the same user on another app" do
    @app1.add_url('MyCoolApp.cloudfoundry.com')
    @app2.add_url('MyCoolApp.cloudfoundry.com')
  end

  it "is not valid if the url has been taken by another user" do
    expect do
      @app1.add_url('MyCoolApp.cloudfoundry.com')
      @app3.add_url('MyCoolApp.cloudfoundry.com')
    end.to raise_error
  end

  it 'is not valid to register a url with different case that is in use by another' do
    expect do
      @app1.add_url('MyCoolApp.cloudfoundry.com')
      @app3.add_url('mycoolAPP.cloudfoundry.com')
    end.to raise_error
  end
end
