# = XXX =
# It's multiplying! This file needs to die in a fire. It is a duplicate of the DEA secure user code.
# Soon we will have a more robust implementation of this, and a better container implementation
# to go with it.

require 'singleton'

require 'vcap/logging'

module VCAP
  module Stager
  end
end

class VCAP::Stager::SecureUserManager
  include Singleton

  SECURE_USER_STRING       = 'vcap-stager-user-'
  SECURE_USER_GREP         = "#{SECURE_USER_STRING}[0-9]\\{1,3\\}"
  SECURE_USER_PATTERN      = /(vcap-stager-user-\d+):[^:]+:(\d+):(\d+)/
  DEFAULT_SECURE_GROUP     = 'vcap-stager'
  SECURE_UID_BASE          = 23000
  DEFAULT_NUM_SECURE_USERS = 32

  def initialize
    @logger = VCAP::Logging.logger('vcap.stager.secure_user_manager')
    unless RUBY_PLATFORM =~ /linux/
      @logger.fatal("ERROR: Secure mode not supported on this platform.")
      exit
    end
  end

  def setup(logger=nil)
    @logger ||= logger
    @logger.info("Grabbing secure users")
    File.umask(0077)
    grab_existing_users
    unless @secure_users.size >= DEFAULT_NUM_SECURE_USERS
      raise "Don't have enough secure users (#{@secure_users.size}), did you forget to set them up? "
    end
    @secure_mode_initialized = true
  end

  def create_secure_users
    if Process.uid != 0
      @logger.fatal "ERROR: Creating secure users requires root priviliges."
      exit 1
    end

    @logger.info "Creating initial #{DEFAULT_NUM_SECURE_USERS} secure users"
    create_default_group
    (1..DEFAULT_NUM_SECURE_USERS).each do |i|
      create_secure_user("#{SECURE_USER_STRING + i.to_s}", SECURE_UID_BASE+i)
    end
  end

  def checkout_user
    raise "Did you forget to call setup_secure_mode()?" unless @secure_mode_initialized

    if @secure_users.length > 0
      ret = @secure_users.pop
      @logger.debug("Checked out #{ret}")
      ret
    else
      raise "All secure users are currently in use."
    end
  end

  def return_user(user)
    raise "Did you forget to call setup_secure_mode()?" unless @secure_mode_initialized
    @logger.debug("Returned #{user}")
    @secure_users << user
  end

  protected

  def create_default_group
    # Add in default group
    system("addgroup --system #{DEFAULT_SECURE_GROUP} > /dev/null 2>&1")
  end

  def create_secure_user(username, uid = 0)
    @logger.info("Creating user:#{username} (#{uid})")
    system("adduser --system --quiet --no-create-home --home '/nonexistent' --uid #{uid} #{username}  > /tmp/foo 2>&1")
    system("usermod -g #{DEFAULT_SECURE_GROUP} #{username}  > /dev/null 2>&1")

    info = get_user_info(username)

    { :user  => username,
      :gid   => info[:gid].to_i,
      :uid   => info[:uid].to_i,
      :group => DEFAULT_SECURE_GROUP,
    }
  end

  def check_existing_users
      return `grep -H "#{SECURE_USER_GREP}" /etc/passwd`
  end

  def grab_existing_users
    @secure_users = []
    File.open('/etc/passwd') do |f|
      while (line = f.gets)
        if line =~ SECURE_USER_PATTERN
          @secure_users <<  { :user => $1, :uid => $2.to_i, :gid => $3.to_i, :group => DEFAULT_SECURE_GROUP}
        end
      end
    end
    @secure_users
  end

  def get_user_info(username)
    info = `id #{username}`
    ret = {}
    ret[:uid] = $1 if info =~ /uid=(\d+)/
    ret[:gid] = $1 if info =~ /gid=(\d+)/
    ret
  end
end
