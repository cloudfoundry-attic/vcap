$:.unshift(File.dirname(__FILE__))

require 'logger'
require 'vcap/subprocess'
require 'user_ops'

module VCAP
  module UserPoolUtil
    class << self
      def init(logger = nil)
        @logger = logger ||  Logger.new(STDOUT)
      end

      def user_from_num(name, num)
        "user-pool-#{name}-#{num}"
      end

      def group_from_name(name)
        "user-pool-#{name}"
      end

      def kill_group_procs(group_name)
        @logger.debug("killing all procs in group #{group_name}")
        #XXX -- fixme VCAP::Subprocess.run("pkill -9 -G #{group_name}" , 0)
      end

      def install_pool(name, size)
        raise ArgumentError("pool name must not contain dashes") if name =~ /-/
        group_name = group_from_name(name)

        @logger.info("Creating user pool #{name} with #{size} users.")
        if VCAP::UserOps.group_exists?(group_name)
          raise ArgumentError.new("group #{group_name} already exists")
        end
        VCAP::UserOps.install_group(group_name)
        kill_group_procs(group_name)

        begin
          1.upto(size) do |number|
            user_name = user_from_num(name, number)
            if VCAP::UserOps.user_exists?(user_name)
              VCAP::UserOps.remove_user(user_name)
              @logger.warn("User reset occured for user #{user_name}!")
            end
            @logger.debug("installing user #{user_name}")
            VCAP::UserOps.install_user(user_name, group_name)
          end
        rescue => e
          @logger.error e.to_s
          @logger.error("pool creation failed, cleaning up")
          remove_pool(name)
        end
      end

      def remove_pool(name)
        @logger.info("Removing user pool #{name}.")
        group_name = group_from_name(name)
        kill_group_procs(group_name)

        Etc.passwd { |u|
          if u.name.split('-')[2] == name
            @logger.debug "removed user #{u.name}"
            VCAP::UserOps.remove_user(u.name)
          end
        }
        Etc.endpwent

        if VCAP::UserOps.group_exists?(group_name)
          VCAP::UserOps.remove_group(group_name)
        else
          @logger.warn "Pool group #{group_name} missing!!"
        end
      end

      def pool_exists?(name)
        group_name = group_from_name(name)
        VCAP::UserOps.group_exists?(group_name)
      end

      def open_pool(name)
        group_name = group_from_name(name)
        pool_users = Hash.new
        unless VCAP::UserOps.group_exists?(group_name)
          raise ArgumentError.new("no group named #{group_name} exists - can't open pool.")
        end
        Etc.passwd { |u|
          if u.name.split('-')[2] == name
            pool_users[u.name] = {:user_name => u.name, :uid => u.uid, :gid => u.gid}
          end
        }
        pool_users
      end

      def pool_list
        list = []
        Etc.group { |g|
          if ['user','pool'] == g.name.split('-')[0..1]
            list.push(g.name.split('-')[2])
          end
        }
        Etc.endgrent
        list.map {|name| "#{name} #{open_pool(name).size}"}
      end

    end
  end
end
