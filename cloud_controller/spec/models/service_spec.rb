require 'spec_helper'

describe Service do
  it "requires a valid label" do
    svc = Service.new
    svc.should have_at_least(1).errors_on(:label)

    svc = Service.new.label = 'foo'
    svc.should have_at_least(1).errors_on(:label)

    svc = Service.new
    svc.label = 'foo-bar'
    svc.should have(0).errors_on(:label)
  end

  it "requires a valid url" do
    svc = Service.new
    svc.should have_at_least(1).errors_on(:url)

    svc = Service.new
    svc.url = 'bar'
    svc.should have_at_least(1).errors_on(:url)

    svc = Service.new
    svc.url = "http://www.google.com"
    svc.should have(0).errors_on(:url)
  end

  it "requires a token" do
    svc = Service.new
    svc.should have_at_least(1).errors_on(:token)

    svc = Service.new
    svc.token = 'foo'
    svc.should have(0).errors_on(:token)
  end

  it "should be valid given (label, url, token)" do
    svc = Service.new
    svc.label = 'foo-bar'
    svc.url   = 'http://www.google.com'
    svc.token = 'foo'
    svc.should be_valid
  end

  it "should enforce uniqueness constraints on labels" do
    svc = make_service(:label => "foo-bar", :url => "http://www.google.com", :token => "foo")
    svc.should be_valid
    svc.save

    svc = make_service(:label => "foo-bar", :url => "http://www.google.com", :token => "foo")
    svc.save
    svc.should_not be_valid
  end

  it "should serialize complex fields" do
    plans = ["foo", "bar"]
    svc = make_service(:label => "foo-bar", :url => "http://www.google.com", :token => "foo", :plans => plans)
    svc.should be_valid
    svc.save

    svc = Service.find_by_label("foo-bar")
    svc.should_not be_nil
    (plans == svc.plans).should be_true
  end

  describe "#visible_to_user?" do
    before :each do
      @user_a = User.new(:email => 'a@bar.com')
      @user_a.set_and_encrypt_password('foo')
      @user_a.should be_valid

      @user_b = User.new(:email => 'b@bar.com')
      @user_b.set_and_encrypt_password('foo')
      @user_b.should be_valid

      @user_c = User.new(:email => 'c@foo.com')
      @user_c.set_and_encrypt_password('foo')
      @user_c.should be_valid

      @svc = make_service(
        :url   => 'http://www.foo.com',
        :plans => ['plan_a', 'plan_b', 'plan_c'],
        :label => 'foo-bar',
        :token => 'foobar'
      )
      @svc.should be_valid

      @user_acl_svc = make_service(
        :url   => 'http://www.foo.com',
        :plans => ['plan_a', 'plan_b', 'plan_c'],
        :label => 'foo-bar1',
        :token => 'foobar',
        :acls  => {'users' => ['a@bar.com'], 'wildcards' => []}
      )
      @user_acl_svc.should be_valid

      @wc_acl_svc = make_service(
        :url   => 'http://www.foo.com',
        :plans => ['plan_a', 'plan_b', 'plan_c'],
        :label => 'foo-bar2',
        :token => 'foobar',
        :acls  => {'users' => [], 'wildcards' => ['*@bar.com']}
      )
      @wc_acl_svc.should be_valid

      @p_acl_svc = make_service(
        :url   => 'http://www.foo.com',
        :plans => ['plan_a', 'plan_b', 'plan_c'],
        :label => 'foo-bar3',
        :token => 'foobar',
        :acls  => {
          'plans' => {
            'plan_a' => {'wildcards' => ['*@bar.com']}
          }
        }
      )
      @p_acl_svc.should be_valid

      @combo_acl_svc = make_service(
        :url   => 'http://www.foo.com',
        :plans => ['plan_a', 'plan_b', 'plan_c'],
        :label => 'foo-bar4',
        :token => 'foobar',
        :acls  => {
          'wildcards' => ['*@bar.com'],
          'plans' => {
            'plan_a' => {'users' => ['a@bar.com']}
          }
        }
      )
      @combo_acl_svc.should be_valid
    end

    it "should return true for services with no acls" do
      @svc.visible_to_user?(@user_a, 'plan_a').should be_true
      @svc.visible_to_user?(@user_a).should be_true
    end

    it "should correctly validate users in the user acl" do
      @user_acl_svc.visible_to_user?(@user_a).should be_true
      @user_acl_svc.visible_to_user?(@user_b).should be_false
    end

    it "should correctly validate users in the wildcard acl" do
      @wc_acl_svc.visible_to_user?(@user_a).should be_true
      @wc_acl_svc.visible_to_user?(@user_b).should be_true
      @wc_acl_svc.visible_to_user?(@user_c).should be_false
    end

    it "should correctly validate user in the plan acls" do
      @p_acl_svc.visible_to_user?(@user_a).should be_true  # can see plan_a, plan_b, plan_c
      @p_acl_svc.visible_to_user?(@user_b).should be_true  # can see plan_a, plan_b, plan_c
      @p_acl_svc.visible_to_user?(@user_c).should be_true  # can see plan_b, plan_c

      @p_acl_svc.visible_to_user?(@user_a, "plan_a").should be_true
      @p_acl_svc.visible_to_user?(@user_b, "plan_a").should be_true
      @p_acl_svc.visible_to_user?(@user_c, "plan_a").should be_false
    end

    it "should correctly validate user in the service acls and the plan acls" do
      @combo_acl_svc.visible_to_user?(@user_a).should be_true    # can see plan_a, plan_b, plan_c
      @combo_acl_svc.visible_to_user?(@user_b).should be_true    # can see plan_b, plan_c
      @combo_acl_svc.visible_to_user?(@user_c).should be_false   # can not see service

      @combo_acl_svc.visible_to_user?(@user_a, "plan_a").should be_true
      @combo_acl_svc.visible_to_user?(@user_b, "plan_a").should be_false
      @combo_acl_svc.visible_to_user?(@user_c, "plan_a").should be_false
    end
  end

  describe "#is_builtin?" do
    it "should correctly check against AppConfig" do
      AppConfig[:builtin_services].delete(:foo)
      svc = Service.new(:label => "foo-bar", :url => "http://www.google.com", :token => "foo")
      svc.is_builtin?.should be_false
      AppConfig[:builtin_services][:foo] = true
      svc.is_builtin?.should be_true
      AppConfig[:builtin_services].delete(:foo)
    end
  end

  describe "#verify_auth_token" do
    it "should verify against AppConfig for builtin services" do
      AppConfig[:builtin_services][:foo] = {:token => 'foo'}
      svc = Service.new(:label => "foo-bar", :url => "http://www.google.com")
      svc.is_builtin?.should be_true
      svc.verify_auth_token('foo').should be_true
      svc.verify_auth_token('bar').should be_false
      AppConfig[:builtin_services].delete(:foo)
    end

    it "should verify against the service for non builtin services" do
      svc = Service.new(:label => "foo-bar", :url => "http://www.google.com", :token => 'bar')
      svc.is_builtin?.should be_false
      svc.verify_auth_token('bar').should be_true
      svc.verify_auth_token('foo').should be_false
    end
  end

  def make_service(opts)
    svc = Service.new
    opts.each do |k, v|
      svc.send("#{k}=", v)
    end
    svc.save
    svc
  end
end
