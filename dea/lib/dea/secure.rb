# Copyright (c) 2009-2011 VMware, Inc.
module DEA
  module Secure

    SECURE_USER_STRING       = 'vcap-user-'
    SECURE_USER_GREP         = "#{SECURE_USER_STRING}[0-9]\\{1,3\\}"
    SECURE_USER_GREP_MAC     = "#{SECURE_USER_STRING}[0-9]"
    SECURE_USER_PATTERN      = /(vcap-user-\d+):[^:]+:(\d+)/
    DEFAULT_SECURE_GROUP     = 'vcap-dea'
    SECURE_UID_BASE          = 22000
    DEFAULT_NUM_SECURE_USERS = 32

    attr_reader :isLinux, :isMacOSX, :secure

    def setup_secure_mode
      return unless @secure
      @isLinux = true if RUBY_PLATFORM =~ /linux/
      @isMacOSX = true if RUBY_PLATFORM =~ /darwin/

      if (!isLinux && !isMacOSX)
        @logger.fatal("Secure mode not supported on this platform."); exit
      end
      if Process.uid != 0
        @logger.fatal("Secure mode requires root privileges."); exit
      end
      File.umask(0077)
      setup_secure_users
    end

    def create_default_group
      # Add in default group
      cmd = "addgroup --system #{DEFAULT_SECURE_GROUP} > /dev/null 2<&1" if isLinux
      cmd = "dscl . -create /Groups/#{DEFAULT_SECURE_GROUP} PrimaryGroupID #{SECURE_UID_BASE}" if isMacOSX
      system(cmd)
    end

    def create_secure_user(username, uid)
      @logger.info("Creating user:#{username} (#{uid})")
      if isLinux
        system("adduser --system --shell '/bin/sh' --quiet --no-create-home --uid #{uid} --home '/nonexistent' #{username}  > /dev/null 2<&1")
        system("usermod -g #{DEFAULT_SECURE_GROUP} #{username}  > /dev/null 2<&1")
      elsif isMacOSX
        system("dscl . -create /Users/#{username} UniqueID #{uid}")
        system("dscl . -create /Users/#{username} PrimaryGroupID #{SECURE_UID_BASE}")
        system("dscl . -create /Users/#{username} UserShell /bin/bash")
      end
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
              @secure_users <<  { :user => $1, :uid => $2, :available => true}
            end
          end
        end
      elsif isMacOSX
        users = check_existing_users.split("\n")
        users.each do |u|
          @secure_users << { :user => u, :uid => -1, :available => true}
        end
      end
    end

    def setup_secure_users
      # First check to see if we have existing users..
      existing = check_existing_users
      if existing.empty?
        @logger.info("Creating initial #{DEFAULT_NUM_SECURE_USERS} secure users")
        create_default_group
        (1..DEFAULT_NUM_SECURE_USERS).each do |i|
          create_secure_user("#{SECURE_USER_STRING + i.to_s}", SECURE_UID_BASE+i)
        end
      end
      grab_existing_users
    end

    def grab_secure_user
      # Attempt to grab a user here, if not create one, only runs on linux and macosx for now.
      @secure_users.each do |u|
        return u if u[:available]
      end

      @logger.info("We have #{@secure_users.size} secure users, allocating more on demand")

      # Just do one for now, on demand..
      num_secure_users = @secure_users.size
      next_index = (num_secure_users + 1)
      name = "#{SECURE_USER_STRING + next_index.to_s}"
      uid = SECURE_UID_BASE + next_index
      create_secure_user(name, uid)
      user = { :user => name, :uid => uid, :available => true}
      @secure_users << user
      user
    end

    def kill_all_procs_for_user(user)
      return unless user
      if isLinux # Ubuntu JeOS does not have killall by default
        `pkill -9 -U #{user[:uid]} > /dev/null 2> /dev/null`
      elsif isMacOSX
        `killall -9 -u #{user[:name]} > /dev/null 2> /dev/null`
      end
    end

    def find_secure_user(username)
      @secure_users.each do |u|
        return u if username == u[:user]
      end
    end
  end
end
