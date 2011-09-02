$:.unshift(File.dirname(__FILE__))

require 'logger'
require 'emrun'
require 'user_ops'
require 'user_pool_defs'

module VCAP
  class UserPool
    attr_accessor :free_users
    attr_accessor :busy_users

    def store_pool_def(pool_def)
      @uid_base   = pool_def[:uid_base]
      @pool_size  = pool_def[:pool_size]
      @group_name = pool_def[:group_name]
      @user_prefix = pool_def[:user_prefix]
    end

    def initialize(pool_def, logger = nil)
      @logger = logger ||  Logger.new(STDOUT)
      @free_users = Hash.new
      @busy_users = Hash.new
      store_pool_def(pool_def)
      EMRun.init(logger)
    end

    def verify_user(user_name, uid, gid)
      entry = Etc.getpwnam(user_name)
      (entry.uid == uid) and (entry.gid == gid)
    end

    #install new user pool.
    def install_pool
      @logger.info("Creating user pool #{@group_name} with #{@pool_size} users.")
      if not UserOps.group_exists?(@group_name)
        UserOps.install_group(@group_name)
      end

      @user_list = create_user_list(@pool_size, @uid_base, @group_name)

      @logger.debug("killing all procs in group #{@group_name}")
      kill_all_group_procs(@group_name)

      @user_list.each do |user|
        user_name = user[:user_name]
        uid = user[:uid]
        gid = user[:gid]
        if UserOps.user_exists?(user_name)
          #force things into a consisent state if they are out of wack and
          #keep going.
          if not verify_user(user_name, uid, gid)
            UserOps.remove_user(user_name)
            UserOps.install_user(user_name, @group_name, uid)
            @logger.warn("User pool corruption occured!")
          end
        else
          UserOps.install_user(user_name, @group_name, uid)
        end
        @free_users[user_name] = user
      end
    end

    def remove_pool
      @logger.debug("killing all procs in group #{@group_name}")
      kill_all_group_procs(@group_name)
      @user_list.each do |user|
        user_name = user[:user_name]
        @logger.debug "removed user #{user_name}"
        UserOps.remove_user(user_name)
      end
      if not UserOps.group_exists?(@group_name)
        @logger.warn "Pool group missing!!"
      else
        UserOps.remove_group(@group_name)
      end
    end

    def alloc_user
      user_name, user = @free_users.shift
      if user_name != nil
        @busy_users[user_name] = user
      else
        raise "out of users!!"
      end
      @logger.debug "alloc()'d user #{user_name}"
      user
    end

    def free_user(user)
      user_name = user[:user_name]
      if @busy_users.has_key?(user_name)
        kill_all_user_procs(user_name)
        @busy_users.delete(user_name)
        @free_users[user_name] = user
        @logger.debug "free()'d user #{user_name}"
      else
        raise "invalid free user: #{user_name}"
      end
    end

    private

    def kill_all_group_procs(group_name)
      VCAP::EMRun.run("pkill -9 -G #{group_name}" , 1)
    end

    def kill_all_user_procs(user_name)
      VCAP::EMRun.run("pkill -9 -u #{user_name}", 1)
    end

    def user_from_num(num)
      "user-pool-#{@user_prefix}-#{num}"
    end

    def create_user_list(pool_size, uid_base, group_name)
      gid = Etc.getgrnam(group_name).gid
      Range.new(1, pool_size).to_a.map { |offset|
        {:user_name => user_from_num(offset), :uid => uid_base + offset, :gid => gid}
      }.freeze
    end

  end
end
