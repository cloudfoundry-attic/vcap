require 'spec_helper'

describe "A GET request to /info" do
  before do
    build_admin_and_user
  end

  it "as an anonymous user" do
    get cloud_info_url
    response.status.should == 200
  end

  shared_examples_for "any request" do
    # This code tests https enforcement in a variety of scenarions defined in cloud_spec_helpers
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
          @current_headers = headers_for(@current_user, nil, nil, (scenario_vars[:protocol]=="https"))
        end

        after do
          # Back to defaults (false)
          AppConfig[:https_required] = false
          AppConfig[:https_required_for_admins] = false
        end

        # These should work in EVERY config scenario
        it "with invalid authorization header for #{scenario_vars[:user]}" do
          headers = @current_headers
          headers['HTTP_AUTHORIZATION'].reverse!
          get cloud_info_url, nil, headers
          response.status.should == 200
          json = Yajl::Parser.parse(response.body)
          json.should_not have_key('user')
        end


        it "with a valid authorization header for #{scenario_vars[:user]}" do
          get cloud_info_url, nil, @current_headers
          response.status.should == (scenario_vars[:success] ? 200 : 403)
          if scenario_vars[:success]
            json = Yajl::Parser.parse(response.body)
            json.should have_key('user')
          end
        end
      end
    end
  end

  context "using conventional tokens" do
    it_should_behave_like "any request"
  end

  context "using jwt tokens" do
    before :all do
      CloudSpecHelpers.use_jwt_token = true
    end

    it_should_behave_like "any request"
  end


end

