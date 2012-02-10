require 'spec_helper'

describe "Creating a new App" do

  shared_examples_for "any request to create a new app" do
    before do
      build_admin_and_user
    end

    it "is successful when given a unique name" do
      data = { 'name' => random_name, 'staging' => {'model' => 'sinatra', 'stack' => 'ruby18' }}
      lambda do
        post app_create_path, nil, headers_for(@user.email, nil, data)
        response.should redirect_to(app_get_url(data['name']))
      end.should change(App, :count).by(1)
    end

    it "fails when given a duplicate name"
  end

  context "using conventional tokens" do
    it_should_behave_like "any request to create a new app"
  end

  context "using jwt tokens" do
    before :all do
      CloudSpecHelpers.use_jwt_token = true
    end

    it_should_behave_like "any request to create a new app"
  end

end
