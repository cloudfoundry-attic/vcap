require 'spec_helper'

describe App do
  it "must have an owner"
  it "requires a unique name/owner combination"
  it "specifies a runtime and framework"
  it "defaults to 0 instances when initialized" do
    App.new.instances.should be_zero
  end

  describe "#collaborators" do
    before :each do
      @user_a = create_user('a@foo.com', 'a')
      @user_b = create_user('b@foo.com', 'b')

      @app = App.create(
        :name      => 'foobar',
        :owner     => @user_a,
        :runtime   => 'ruby18',
        :framework => 'sinatra')
      @app.should be_valid
    end

    it "includes the owner by default" do
      @app.collaborator?(@user_a).should be_true
    end

    it "can be added" do
      @app.add_collaborator(@user_b)
      @app.collaborator?(@user_b).should be_true
    end

    it "can be removed" do
      @app.remove_collaborator(@user_a)
      @app.collaborator?(@user_a).should be_false
    end
  end

  describe '#update_run_count' do
    before :each do
      @app = App.new
    end

    it 'resets the run count if the staged package hash changed' do
      @app.expects(:staged_package_hash_changed?).returns(true)
      @app.run_count = 5
      @app.update_run_count()
      @app.run_count.should == 0
    end

    it 'increments the run count if the staged package hash did not change' do
      @app.expects(:staged_package_hash_changed?).returns(false)
      @app.run_count = 5
      @app.update_run_count()
      @app.run_count.should == 6
    end
  end

  def create_user(email, pw)
    u = User.new(:email => email)
    u.set_and_encrypt_password(pw)
    u.save
    u.should be_valid
    u
  end
end
