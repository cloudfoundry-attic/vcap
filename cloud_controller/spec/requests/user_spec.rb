require 'spec_helper'

describe "A request to create a new user" do
  describe "from localhost" do
    it "is accepted without further authorization" do
      json_body = {:email => 'user_request_spec@example.com', :password => 'example'}
      post create_user_path, nil, headers_for(nil, nil, json_body)
      response.should be_success
    end
  end

  describe "from a remote address" do
    describe "with remote registration disabled" do
      it "is accepted with admin authorization"
      it "is rejected"
    end

    # TODO - Can be a shared spec with 'from localhost' above
    describe "with remote registration enabled" do
      before do
        # Enable remote registration and set a remote address here.
        # Remember to un-set it in an after hook
      end
      it "is accepted without further authorization" do
      end
    end
  end
end

describe "A request to delete an existing user" do
  before do
    # create a user for the admin to destroy
  end

  describe "from localhost" do
    it "is accepted without further authorization"
    it "is rejected if the user does not exist"
  end

  describe "from a remote address" do
    describe "with remote registration disabled" do
      it "is accepted with admin authorization"
      it "is rejected if the user does not exist"
      it "is rejected for non-admins"
    end

    # TODO - Can be a shared spec with 'from localhost' above
    describe "with remote registration enabled" do
      it "is accepted without further authorization"
      it "is rejected if the user does not exist"
    end
  end
end
