class Service < ActiveRecord::Base
  LABEL_REGEX = /^\S+-\S+$/

  # TODO - Blacklist of reserved names
  has_many :service_configs, :dependent => :destroy
  has_many :service_bindings, :through => :service_configs
  validates_presence_of :label, :url, :token
  validates_uniqueness_of :label

  validates_format_of :url, :with => URI::regexp(%w(http https))
  validates_format_of :info_url, :with => URI::regexp(%w(http https)), :allow_nil => true
  validates_format_of :label, :with => LABEL_REGEX
  validate :cf_plan_id_matches_plans

  serialize :tags
  serialize :plans
  serialize :cf_plan_id
  serialize :plan_options
  serialize :binding_options
  serialize :acls

  attr_accessible :label, :token, :url, :description, :info_url, :tags, :plans, :cf_plan_id, :plan_options, :binding_options, :active, :acls, :timeout

  def self.active_services
    where("active = ?", true)
  end

  def label=(label)
    super
    self.name, _, self.version = self.label.rpartition(/-/) if self.label
  end

  # Predicate function that returns true if the service is visible to the supplied
  # user. False otherwise.
  #
  # There are two parts of acls. One is service acls applied to service as a whole
  # One is plan acls applied to specific service plan.
  #
  # A example of acls structure:
  # acls:
  #   users:              #service acls
  #   - foo@bar.com
  #   - foo1@bar.com
  #   wildcards:          #service acls
  #   - *@foo.com
  #   - *@foo1.com
  #   plans:
  #     plan_a:           #plan acls
  #       users:
  #       - foo2@foo.com
  #       wildcards:
  #       - *@foo1.com
  #
  # The following chart shows service visibility:
  #
  # P_ACLs\S_ACLs | Empty       | HasACLs                    |
  #   Empty       | True        | S_ACL(user)                |
  #   HasACLs     | P_ACL(user) | S_ACL(user) && P_ACL(user) |
  def visible_to_user?(user, plan=nil)
    return false if !plans || !user.email
    return true unless acls

    if !plan
      plans.each do |p|
        return true if visible_to_user?(user, p)
      end
      return false
    else
      # for certain plan, user should match service acls and plan acls
      p_acls = acls["plans"] && acls["plans"][plan]
      validate_by_acls?(user, acls) && validate_by_acls?(user, p_acls)
    end
  end

  # Return true if acls is empty or user matches user list or wildcards
  # false otherwise.
  def validate_by_acls?(user, acl)
    !acl ||
    (!acl["users"] && !acl["wildcards"]) ||
    user_in_userlist?(user, acl["users"]) ||
    user_match_wildcards?(user, acl["wildcards"])
  end

  # Returns true if the user's email is contained in the set of user emails
  # false otherwise
  def user_in_userlist?(user, userlist)
    userlist && userlist.include?(user.email)
  end

  # Returns true if user matches any of the wildcards
  # false otherwise.
  def user_match_wildcards?(user, wildcards)
    wildcards.each do |wc|
      re_str = Regexp.escape(wc).gsub('\*', '.*?')
      return true if user.email =~ /^#{re_str}$/
    end if wildcards

    false
  end

  # Returns the service represented as a legacy hash
  def as_legacy(user)
    # Synthesize tier info
    tiers = {}

    # Sort order expects to be keyed starting at 1 :/
    sort_orders = {}
    self.plans.sort.each_index do |i|
      sort_orders[self.plans[i]] = i + 1
    end

    self.plans.each do |p|
      next unless visible_to_user?(user, p)
      tiers[p] = {
        :options => {},
        :order   => sort_orders[p],  # XXX - Sort order. Synthesized for now (alphabetical), may want to add support for this to svcs api.
      }
      if self.plan_options.is_a?(Hash) && self.plan_options.has_key?(p)
        # Binding options should be included as well, but no longer
        # make sense as they are all strings...
        tiers[p][:options][:plan_option] = {
          :type        => 'value',
          :description => 'Which plan would you like to use',
          :values      => self.plan_options[p],
        }
      end
    end

    { :id      => self.id,
      :vendor  => self.name,
      :version => self.version,
      :tiers   => tiers,
      :type    => self.synthesize_service_type,
      :description => self.description || '-',
    }
  end

  # Service types no longer exist, synthesize one if possible to be legacy api compliant
  def synthesize_service_type
    case self.name
    when /mysql/
      'database'
    when /postgresql/
      'database'
    when /redis/
      'key-value'
    when /mongodb/
      'key-value'
    else
      'generic'
    end
  end

  def is_builtin?
    AppConfig.has_key?(:builtin_services) && AppConfig[:builtin_services].has_key?(self.name.to_sym)
  end

  def verify_auth_token(token)
    if is_builtin?
      (AppConfig[:builtin_services][self.name.to_sym][:token] == token)
    else
      (self.token == token)
    end
  end

  def hash_to_service_offering
    svc_offering = {
      :label => self.label,
      :url   => self.url
    }
    svc_offering[:description]     = self.description     if self.description
    svc_offering[:info_url]        = self.info_url        if self.info_url
    svc_offering[:tags]            = self.tags            if self.tags
    svc_offering[:plans]           = self.plans           if self.plans
    svc_offering[:cf_plan_id]      = self.cf_plan_id      if self.cf_plan_id
    svc_offering[:plan_options]    = self.plan_options    if self.plan_options
    svc_offering[:binding_options] = self.binding_options if self.binding_options
    svc_offering[:acls]            = self.acls            if self.acls
    svc_offering[:active]          = self.active          if self.active
    svc_offering[:timeout]         = self.timeout         if self.timeout
    return svc_offering
  end

  def cf_plan_id_matches_plans
    # cf_plan_id either be nil,
    # or its keys must be a subset of plans
    if cf_plan_id && !(cf_plan_id.is_a?(Hash) && plans.is_a?(Array) && (cf_plan_id.keys - plans).empty?)
      errors.add(:base, "cf_plan_id does not match plans")
    end
  end
end
