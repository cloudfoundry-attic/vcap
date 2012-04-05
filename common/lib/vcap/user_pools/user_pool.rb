$:.unshift(File.join(File.dirname(__FILE__),'..'))
$:.unshift(File.dirname(__FILE__))
require 'user_pool_util'
require 'user_ops'
require 'subprocess'

module VCAP
  class UserPool
    attr_accessor :free_users
    attr_accessor :busy_users

    def initialize(name, logger = nil)
      @logger = logger ||  Logger.new(STDOUT)
      UserPoolUtil.init
      @free_users = UserPoolUtil.open_pool(name)
      @busy_users = Hash.new
      @logger.debug("Initialized user pool #{name} with #{@free_users.size} users.")
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
        VCAP::Subprocess.run("pkill -9 -u #{user_name}", 1)
        @busy_users.delete(user_name)
        @free_users[user_name] = user
        @logger.debug "free()'d user #{user_name}"
      else
        raise "invalid free user: #{user_name}"
      end
    end
  end
end


