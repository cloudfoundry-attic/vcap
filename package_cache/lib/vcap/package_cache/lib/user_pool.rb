$:.unshift(File.join(File.dirname(__FILE__)))

require 'logger'
require 'user_ops'
require 'thread'
require 'vdebug'
require 'user_pool_defs'
require 'emrun'

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
      @free_users = []
      @busy_users = []
      @users_mutex = Mutex.new
      store_pool_def(pool_def)
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
          raise "User pool corruption!!!" if not verify_user(user_name, uid, gid)
        else
          UserOps.install_user(user_name, @group_name, uid)
        end
        @free_users << user
      end
    end

    def remove_pool
      @logger.debug("killing all procs in group #{@group_name}")
      kill_all_group_procs(@group_name)

      #XXX should call verify user in inner loop to ensure group kill
      #XXX was sufficient.
      @user_list.each do |user|
        user_name = user[:user_name]
        @logger.debug "remove user #{user_name}"
        UserOps.remove_user(user_name)
      end
      if not UserOps.group_exists?(@group_name)
        @logger.warn "Pool group missing!!"
      else
        UserOps.remove_group(@group_name)
      end
    end

    def alloc_user
      fresh_user = nil
      @users_mutex.synchronize do
        fresh_user = @free_users.pop
        if fresh_user != nil
          @busy_users.push(fresh_user)
        else
          raise "out of users!!"
        end
      end
      @logger.debug "alloc()'d user #{fresh_user}"
      fresh_user
    end


    def free_user(user)
      user_name = user[:user_name]
      @users_mutex.synchronize do
        if not user_in_list?(@busy_users, user_name)
          raise "tried to free user: #{user_name} not currently in use!"
        end
        if not user_in_list?(@user_list, user_name)
          raise "tried to free invalid user: #{user_name}"
        end
        @busy_users.delete_if { |name, uid| name == user_name}
        @free_users.push(user)
      end
      kill_all_user_procs(user_name)
      @logger.debug "free()'d user #{user_name}"
    end

    def user_in_use?(user)
      user_name = user[:user_name]
      result = false
      @users_mutex.synchronize do
        result = user_in_list?(@busy_users, user_name)
      end
      result
    end

    private

    def kill_all_group_procs(group_name)
      begin
         EMRun.run("pkill -9 -G #{group_name} 2>&1", 1)
         #UserOps.run("pkill -9 -G #{group_name} 2>&1", 1)
      rescue => e
        @logger.warn "unexpected running processes in user pool group #{group_name}"
      end
    end

    def kill_all_user_procs(user_name)
      begin
        VCAP::EMRun.run("pkill -9 -u #{user_name} 2>&1", 1)
        #UserOps.run("pkill -9 -u #{user_name} 2>&1", 1)
      rescue => e
        @logger.warn "unexpected running processes for free'd user #{user_name}"
      end
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

    #helpers.. don't acquire mutex.
    def user_in_list?(list, user_name)
      list.each { |user| return true if user[:user_name] == user_name }
      false
    end
  end
end
