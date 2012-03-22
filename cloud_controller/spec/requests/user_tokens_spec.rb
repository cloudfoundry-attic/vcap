require 'spec_helper'

describe "Requesting a new user token" do

  before do
    build_admin_and_user

    @admin_token_path = create_token_path('email' => @admin.email)
    @user_token_path = create_token_path('email' => @user.email)
  end

  shared_examples_for "any request for a new user token" do
    it "returns a 400 response when given invalid JSON" do
      bad_data = '{{{}}}'
      post @admin_token_path, nil, headers_for(@admin.email, nil, bad_data)
      response.status.should == 400
    end

    it "always returns a 200 response when admin requests" do
      post @user_token_path, nil, headers_for(@admin.email, nil, '{}')
      response.status.should == 200
    end
  end

  context "using conventional tokens" do
    it_should_behave_like "any request for a new user token"
  end

  context "using jwt tokens" do
    before :all do
      CloudSpecHelpers.use_jwt_token = true
    end

    it_should_behave_like "any request for a new user token"
  end

  context "When user_expire is specified" do
    before { UserToken.token_expire = 1.day }
    let :token do
      json = Yajl::Parser.parse(response.body)
      token = UserToken.decode(json['token'])
    end

    context "and a token was published 25 hours ago" do
      before do
        Delorean.time_travel_to "25 hours ago" do
          post @user_token_path, {"password" => @user_password}.to_json, {'X-Forwarded_Proto' => 'http'}
        end
      end
      it "should return a 200 response" do
        response.should be_ok
      end
      it "a given token should be expired" do
        token.should be_expired
      end
      it "a given token should not be valid since it's expired." do
        token.should_not be_valid
      end
    end

    context "and a token was published within 1 day" do
      before do
        Delorean.time_travel_to "23 hours ago" do
          post @user_token_path, {"password" => @user_password}.to_json, {'X-Forwarded_Proto' => 'http'}
        end
      end
      it "should return a 200 response" do
        response.should be_ok
      end
      it "a given token should not be expired" do
        token.should_not be_expired
      end
      it "a given token should be valid." do
        token.should be_valid
      end

    end
  end

  # This code tests https enforcement in a variety of scenarios defined in cloud_spec_helpers.rb
  CloudSpecHelpers::HTTPS_ENFORCEMENT_SCENARIOS.each do |scenario_vars|
    describe "#{scenario_vars[:appconfig_enabled].empty? ? '' : 'with ' + (scenario_vars[:appconfig_enabled].map{|x| x.to_s}.join(', ')) + ' enabled'} using #{scenario_vars[:protocol]}" do
      before do
        # Back to defaults (false)
        AppConfig[:https_required] = false
        AppConfig[:https_required_for_admins] = false

        scenario_vars[:appconfig_enabled].each do |v|
          AppConfig[v] = true
        end

        @current_user = instance_variable_get("@#{scenario_vars[:user]}")
        @current_password_json = {"password" => instance_variable_get("@#{scenario_vars[:user]}_password")}.to_json
        @current_token_path = instance_variable_get("@#{scenario_vars[:user]}_token_path")

        @current_headers = {'X-Forwarded_Proto' => scenario_vars[:protocol]}
      end

      after do
        # Back to defaults (false)
        AppConfig[:https_required] = false
        AppConfig[:https_required_for_admins] = false
      end

      it "and #{scenario_vars[:user]} is logging in" do
        post @current_token_path, @current_password_json, @current_headers
        response.status.should == (scenario_vars[:success] ? 200 : 403)
      end
    end
  end
end
