$:.unshift(File.join(File.dirname(__FILE__)))

require 'logger'
require 'user_ops'
require 'thread'

# XXX come up with better way to store pool specs.

$test_pool = { :uid_base => 31000,
              :pool_size => 5,
              :user_prefix => 'test-pool-user',
              :group_name => 'test-pool-group'
}

class UserPool
  attr_accessor :free_users
  attr_accessor :busy_users

  def initialize(logger = nil)
    UserOps.init
    @logger = logger ||  Logger.new(STDOUT)
    @free_users = []
    @busy_users = []
    @users_mutex = Mutex.new
  end

  #this does a hard setup of a new pool,
  #destroys all existing user procs in the
  #pool on setup.
  def user_from_num(num)
    "#{@user_prefix}-#{num}"
  end

  def init_locals(pool_spec)
    @uid_base   = pool_spec[:uid_base]
    @pool_size  = pool_spec[:pool_size]
    @group_name = pool_spec[:group_name]
    @user_prefix = pool_spec[:user_prefix]
  end
  #install new user pool.
  # -install any users not currently existing.
  # -blow away any associated running processes in with a group
  # or user id in this pool.
  def install_pool(pool_spec)
    init_locals(pool_spec)
    if not UserOps.group_exists?(@group_name)
      UserOps.install_group(@group_name)
    end

    @logger.debug("killing all procs in group #{@group_name}")
    UserOps.group_kill_all_procs(@group_name)

    # XXX should add a generator to return list of user_name,uid pairs to
    # itterate on.
    1.upto(@pool_size) do |offset|
      user_name = user_from_num(offset)
      uid = @uid_base + offset
      if UserOps.user_exists?(user_name)
        raise "User pool corruption!!!" if UserOps.user_to_uid(user_name) != uid.to_s
      else
        UserOps.install_user(user_name, @group_name, uid)
      end
      # XXX should rename to kill_all_user_procs/kill_all_group_procs
      UserOps.user_kill_all_procs(user_name)
      @free_users << {:user_name => user_name, :uid => uid}
    end
  end

  def remove_pool(pool_spec = nil)
    init_locals(pool_spec) if pool_spec != nil
    1.upto(@pool_size) do |offset|
      user_name = user_from_num(offset)
      @logger.debug "remove user #{user_name}"
      UserOps.user_kill_all_procs(user_name)
      UserOps.remove_user(user_name)
    end
    if not UserOps.group_exists?(@group_name)
      @logger.warn "Pool group missing!!"
    else
      UserOps.remove_group(@group_name)
    end
  end

  #XXX this currently just returns nil if we can't allocate a user,
  #XXX should this throw an exception?
  def alloc_user
    fresh_user = nil
    @users_mutex.synchronize do
      fresh_user = @free_users.pop
      if fresh_user != nil
        @busy_users.push(fresh_user)
      end
    end
    @logger.debug "alloc()'d user #{fresh_user}"
    fresh_user
  end

  def free_user(user_name)
    @users_mutex.synchronize do
      if not user_in_list?(@busy_users, user_name)
        raise "tried to free user: #{user_name} not currently in use!"
      end
      if not user_in_list?(users(), user_name)
        raise "tried to free invalid user: #{user_name}"
      end
      UserOps.user_kill_all_procs(user_name)
      @busy_users.delete_if { |k,v| k == user_name}
      @free_users.push(user_name)
    end
    @logger.debug "free()'d user #{user_name}"
  end

  private:

  #helpers.. don't acquire mutex.
  def users
    (@free_users + @busy_users).sort_by {|user| user[:uid]}
  end

  def user_in_list?(list, user_name)
    list.each { |k,v| return true if k == user_name }
    false
  end

end

