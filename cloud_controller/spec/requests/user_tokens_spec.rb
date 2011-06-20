require 'spec_helper'

describe "Requesting a new user token" do
  before do
    build_admin_and_user

    @admin_token_path = create_token_path('email' => @admin.email)
    @user_token_path = create_token_path('email' => @user.email)
  end

  it "returns a 400 response when given invalid JSON" do
    bad_data = '{{{}}}'
    post @admin_token_path, nil, headers_for(@admin.email, nil, bad_data)
    response.status.should == 400
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
