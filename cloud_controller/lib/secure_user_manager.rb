# = XXX =
# This file needs to die in a fire. It is a duplicate of the DEA secure user code.
# Staging needs to be moved to the DEA, or at the very least this needs to be
# refactored and tests need to be written.

require 'logger'
require 'singleton'

class SecureUserManager
  include Singleton

  SECURE_USER_STRING       = 'vcap-cc-user-'
  SECURE_USER_GREP         = "#{SECURE_USER_STRING}[0-9]\\{1,3\\}"
  SECURE_USER_GREP_MAC     = "#{SECURE_USER_STRING}[0-9]"
  SECURE_USER_PATTERN      = /(vcap-cc-user-\d+):[^:]+:(\d+):(\d+)/
  DEFAULT_SECURE_GROUP     = 'vcap-dea'
  SECURE_UID_BASE          = 21000
  DEFAULT_NUM_SECURE_USERS = 32

  attr_reader :isLinux, :isMacOSX, :secure

  def initialize
    @logger = Logger.new(STDOUT)

    @isLinux = true if RUBY_PLATFORM =~ /linux/
    @isMacOSX = true if RUBY_PLATFORM =~ /darwin/

    if (!isLinux && !isMacOSX)
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
      raise "Don't have enough secure users (#{@secure_users.size}), did you forget to set them up?"
    end
    @secure_mode_initialized = true
  end

  def grab_secure_user
    raise "Did you forget to call setup_secure_mode()?" unless @secure_mode_initialized

    # Attempt to grab a user here, if not create one, only runs on linux and macosx for now.
    @secure_users.each do |u|
      if u[:available]
        u[:available] = false
        return u
      end
    end

    raise "All secure users are currently in use. We have #{@secure_users.size} secure users."
  end

  def return_secure_user(user)
    raise "Did you forget to call setup_secure_mode()?" unless @secure_mode_initialized
    user[:available] = true
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

  protected

  def create_default_group
    # Add in default group
    cmd = "addgroup --system #{DEFAULT_SECURE_GROUP} > /dev/null 2>&1" if isLinux
    cmd = "dscl . -create /Groups/#{DEFAULT_SECURE_GROUP} PrimaryGroupID #{SECURE_UID_BASE}" if isMacOSX
    system(cmd)
  end

  def create_secure_user(username, uid = 0)
    @logger.info("Creating user:#{username} (#{uid})")
    if isLinux
      system("adduser --system --quiet --no-create-home --home '/nonexistent' --uid #{uid} #{username}  > /tmp/foo 2>&1")
      system("usermod -g #{DEFAULT_SECURE_GROUP} #{username}  > /dev/null 2>&1")
    elsif isMacOSX
      system("dscl . -create /Users/#{username} UniqueID #{uid}")
      system("dscl . -create /Users/#{username} PrimaryGroupID #{SECURE_UID_BASE}")
      system("dscl . -create /Users/#{username} UserShell /bin/bash")
    end

    info = get_user_info(username)

    { :user  => username,
      :gid   => info[:gid],
      :uid   => info[:uid],
      :group => DEFAULT_SECURE_GROUP,
      :available => true,
    }
  end

  def check_existing_users
    if isLinux
      return `grep -H "#{SECURE_USER_GREP}" /etc/passwd`
    elsif isMacOSX
      return `dscl . -list /Users | grep #{SECURE_USER_GREP_MAC}`
    end
  end

  def grab_existing_users
    @secure_users = []
    if isLinux
      File.open('/etc/passwd') do |f|
        while (line = f.gets)
          if line =~ SECURE_USER_PATTERN
            @secure_users <<  { :user => $1, :uid => $2, :gid => $3, :available => true, :group => DEFAULT_SECURE_GROUP}
          end
        end
      end
    elsif isMacOSX
      users = check_existing_users.split("\n")
      users.each do |u|
        info = get_user_info(u)
        user = {
          :user => u,
          :uid  => info[:uid],
          :gid  => info[:gid],
          :available => true,
          :group => DEFAULT_SECURE_GROUP
        }
        @secure_users << user
      end
    end
  end

  def get_user_info(username)
    info = `id #{username}`
    ret = {}
    ret[:uid] = $1 if info =~ /uid=(\d+)/
    ret[:gid] = $1 if info =~ /gid=(\d+)/
    ret
  end
end
