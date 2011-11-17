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

  serialize :tags
  serialize :plans
  serialize :plan_options
  serialize :binding_options
  serialize :acls

  attr_accessible :label, :token, :url, :description, :info_url, :tags, :plans, :plan_options, :binding_options, :active, :acls, :timeout

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
  # NB: This is currently a stub. When we implement scoped services it will be filled in.
  def visible_to_user?(user)
    (!self.acls || user_in_userlist?(user) || user_match_wildcards?(user))
  end

  # Returns true if the user's email is contained in the set of user emails
  def user_in_userlist?(user)
    return false if (!self.acls || self.acls['users'].empty? || !user.email)
    return true if self.acls['users'].empty?
    Set.new(self.acls['users']).include?(user.email)
  end

  # Returns true if user matches any of the wildcards, false otherwise.
  def user_match_wildcards?(user)
    return false if (!self.acls || self.acls['wildcards'].empty? || !user.email)
    for wc in self.acls['wildcards']
      parts = wc.split('*')
      re_str = parts.map{|p| Regexp.escape(p)}.join('.*')
      if Regexp.new("^#{re_str}$").match(user.email)
        return true
      end
    end
    false
  end

  # Returns the service represented as a legacy hash
  def as_legacy
    # Synthesize tier info
    tiers = {}

    # Sort order expects to be keyed starting at 1 :/
    sort_orders = {}
    self.plans.sort.each_index do |i|
      sort_orders[self.plans[i]] = i + 1
    end

    self.plans.each do |p|
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
end
