require 'spec_helper'

describe User do
  it "is valid given an email address and password" do
    user = User.new :email => "vmware@example.com"
    user.set_and_encrypt_password("password")
    user.should be_valid
  end

  it "requires an email address" do
    user = User.new
    user.should have_at_least(1).errors_on(:email)
  end

  it "requires a valid password" do
    user = User.new
    user.should have_at_least(1).errors_on(:crypted_password)
    lambda do
      user.set_and_encrypt_password(nil)
    end.should raise_error(ActiveRecord::RecordInvalid)
  end

  describe "#account_capacity" do
    before do
      @admin, @default = AccountCapacity.admin, AccountCapacity.default
      User.admins = %w[admin@example.com]
    end

    it "returns AccountCapacity.admin for admins" do
      user = User.new(:email => 'admin@example.com')
      AccountCapacity.expects(:admin).returns(@admin)
      user.account_capacity.should == @admin
    end

    it "returns AccountCapacity.default for users" do
      user = User.new(:email => 'sadmin@example.com')
      AccountCapacity.expects(:default).returns(@default)
      user.account_capacity.should == @default
    end
  end

  describe "#admin?" do
    before do
      User.admins = %w[admin@example.com]
    end

    it "checks the list of configured admins" do
      User.new(:email => "root@example.com").should_not be_admin
      User.new(:email => "admin@example.com").should be_admin
    end
  end

  describe "#apps" do
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

    it "lists all apps the user owns" do
      @user_a.apps.length.should == 1
      @user_a.apps[0].should == @app
    end

    it "lists all apps the user may modify" do
      @app.add_collaborator(@user_b)
      @user_b.apps.length.should == 1
      @user_b.apps[0].should == @app
    end
  end

  describe "#apps_owned" do
    before :each do
      @user_a = create_user('a@foo.com', 'a')
      @user_b = create_user('b@foo.com', 'b')

      @app = App.create(
        :name      => 'foobar',
        :owner     => @user_a,
        :runtime   => 'ruby18',
        :framework => 'sinatra')
      @app.should be_valid
      @app.add_collaborator(@user_b)
    end

    it "should only list apps the user owns" do
      @user_b.apps_owned.length.should == 0
    end
  end

  describe "#uses_new_stager?" do
    it 'should return false if no percent is configured in the config' do
      u = User.new(:email => 'foo@bar.com')
      u.uses_new_stager?({:staging => {}}).should be_false
    end

    it 'should correctly identify which users should have the new stager enabled by percent' do
      u = User.new(:email => 'foo@bar.com')
      cfg  = {:staging => {:new_stager_percent => 2}}

      u.id = 2
      u.uses_new_stager?(cfg).should be_false

      u.id = 250
      u.uses_new_stager?(cfg).should be_false

      u.id = 1
      u.uses_new_stager?(cfg).should be_true

      u.id = 101
      u.uses_new_stager?(cfg).should be_true
    end

    it 'should correctly identify which users should have the new stager enabled by email' do
      u1 = User.new(:email => 'mpage@vmware.com')
      u2 = User.new(:email => 'bar@foo.com')
      cfg  = {:staging => {:new_stager_email_regexp => Regexp.new('.*@vmware\.com')}}

      u1.uses_new_stager?(cfg).should be_true
      u2.uses_new_stager?(cfg).should be_false
    end
  end

  describe '#create_bootstrap_user' do
    before :each do
      @email = 'foo@bar.com'
      @pass  = 'test'
    end

    it 'should create users if they do not exist' do
      User.find_by_email(@email).should be_nil
      User.create_bootstrap_user(@email, @pass).should_not be_nil
      User.find_by_email(@email).should_not be_nil
    end

    it 'should update existing users' do
      oldpass = 'test1'
      newpass = 'test2'
      create_user(@email, oldpass)
      User.create_bootstrap_user(@email, newpass).should_not be_nil
      User.valid_login?(@email, newpass).should be_true
    end

    it 'should update User.admins if the user is an admin' do
      User.admins.include?(@email).should_not be_true
      User.create_bootstrap_user(@email, @pass, true)
      User.admins.include?(@email).should be_true
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
