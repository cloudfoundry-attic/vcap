require 'bcrypt'
require 'rfc822'

class User < ActiveRecord::Base
  has_many :app_collaborations, :dependent => :destroy

  # All apps the user may modify
  has_many :apps, :through => :app_collaborations

  # All apps the user owns (defaults to creator)
  has_many :apps_owned, :class_name => 'App', :foreign_key => :owner_id

  has_many :services # owned

  has_many :service_configs, :dependent => :destroy # provisioned

  # XXX - what should we do here with collaborators?
  has_many :service_bindings,
           :through    => :apps,
           :finder_sql => proc { "SELECT * FROM service_bindings" +
                                 " INNER JOIN apps ON service_bindings.app_id = apps.id" +
                                 " WHERE (apps.owner_id = #{id})" }
  # has_many :routes, :through => :apps

  validates_format_of :email, :with => RFC822::EmailFormat
  validates_uniqueness_of :email, :if => Proc.new {|o| !o.email.blank?}
  validates_presence_of :crypted_password

  class << self
    attr_writer :admins

    def admins
      @admins ||= []
    end

    def valid_login?(email, password)
      if user = find_by_email(email)
        BCrypt::Password.new(user.crypted_password) == password
      end
    end

    def from_token(user_token)
      if user_token.valid?
        find_by_email(user_token.email)
      end
    end

    def all_email_addresses
      connection.select_values "select email from users"
    end

    # Called at startup to seed the database with initial users
    # if they do not yet exist.
    def create_bootstrap_user(email, password, is_admin=false, is_hashed_password=false)
      user = User.find_or_create_by_email(email)
      if is_hashed_password
        user.set_password(password)
      else
        user.set_and_encrypt_password(password)
      end

      user.save!
      admins << email if is_admin
      user
    end
  end

  def set_and_encrypt_password(val)
    raise ActiveRecord::RecordInvalid.new(self) unless val
    self.crypted_password = BCrypt::Password.create(val).to_s
  end

  def set_password(val)
    raise ActiveRecord::RecordInvalid.new(self) unless val
    self.crypted_password = val
  end

  def admin?
    self.class.admins.include?(email)
  end

  def account_capacity
    admin? ? AccountCapacity.admin : AccountCapacity.default
  end

  def account_usage
    app_num = 0
    app_mem = 0
    apps_owned.started.each do |app|
      app_num += 1
      app_mem += (app.memory * app.instances)
    end
    {:memory => app_mem, :apps => app_num, :services => service_configs.count}
  end

  def get_apps
    entries = []
    health_request = []
    apps.each do |app|
      entries << app
      if app.started?
        health_request << { :droplet => app.id, :version => app.generate_version }
      end
    end
    health = ::App.health(health_request)
    entries.collect do |app|
      hash = app.as_json
      hash[:runningInstances] = health[app.id]
      hash
    end
  end

  # This assumes the request is for an app that will be started
  def has_memory_for?(total_instances, memory_per_instance, existing, previous_state)
    quota        = account_capacity[:memory]
    used         = account_usage[:memory]
    total_needed = memory_per_instance.to_i * total_instances.to_i
    extra_needed = total_needed - existing
    extra_needed <= (quota - used)
  end

  # Returns the actual current count of apps, or nil if there is room.
  def no_more_apps?
    count = apps_owned.count
    if account_capacity[:apps] <= count
      count
    end
  end


  def uses_new_stager?(cfg=AppConfig)
    stg = cfg[:staging]
    if (stg[:new_stager_percent] && ((self.id % 100) < stg[:new_stager_percent])) \
       || (stg[:new_stager_email_regexp] && stg[:new_stager_email_regexp].match(self.email))
      true
    else
      false
    end
  end
end
