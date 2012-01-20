require 'spec_helper'

describe "bulk api" do

  before do
    build_admin_and_user
    make_a_bunch_of_apps
  end

  describe 'bulk#apps' do
    it "accepts request without token" do
      get bulk_apps_url
      response.status.should == 200
    end

    it "returns bulk_token with the intial request" do
      get bulk_apps_url
      token.should_not be_nil
    end

    it "returns results in the response.body" do
      get bulk_apps_url
      results.should_not be_nil
    end

    it "respects the batch_size parameter" do
      [3,5].each { |size|
        get bulk_apps_url, {:batch_size=>size}
        results.size.should == size
      }
    end

    it "returns non-intersecting results when token is supplied" do
      size = 2
      get bulk_apps_url, {:batch_size => size}
      saved_results = results
      saved_results.size.should == size
      get bulk_apps_url, {:bulk_token => token, :batch_size=>size}
      results.size.should == size
      saved_results.each {|saved_result| results.should_not include(saved_result) }
    end

    it "should eventually return entire collection, batch after batch" do

      args = {:batch_size => 2}
      apps = {}

      total_size = App.count

      while apps.size < total_size do
        get bulk_apps_url, args
        apps.merge! results
        args[:bulk_token] = token
      end

      apps.size.should == total_size
      get bulk_apps_url, args
      results.size.should == 0
    end

  end

  def token
    body['bulk_token']
  end

  def results
    body['results']
  end

  def body
    Yajl::Parser.parse(response.body)
  end

  def make_a_bunch_of_apps(n=10)

    n.times do
      data = { 'name' => random_name, 'staging' => {'model' => 'sinatra', 'stack' => 'ruby18' }}
      lambda do
        post app_create_path, nil, headers_for(@user.email, nil, data)
        response.should redirect_to(app_get_url(data['name']))
      end.should change(App, :count).by(1)
    end
  end
end
