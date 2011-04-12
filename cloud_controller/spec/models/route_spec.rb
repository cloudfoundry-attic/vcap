require 'spec_helper'

describe Route do
  before do
    @user1 = build_user('route1@example.com')
    @user2 = build_user('route2@example.com')
    # user1 owns app1 and app2, user2 is trying to create app3
    @app1 = App.new(:name => 'app1', :owner => @user1)
    @app2 = App.new(:name => 'app2', :owner => @user1)
    @app3 = App.new(:name => 'app3', :owner => @user2)
  end

  it "is not valid if the url has been taken by another user"

  it "is valid if the url is already used by the same user on another app"
end
