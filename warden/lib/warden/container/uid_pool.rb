require "warden/logger"
require "warden/container/spawn"

module Warden
  module Container

    class UidPool
      extend Logger
      include Spawn

      class NoUidAvailable < WardenError; end

      class << self
        # Returns a UidPool object that will manage +count+ uids from
        # +pool_name+. The pool will be created if it doesn't exist.  Users
        # belonging to this pool will have usernames of the form
        # "<pool_name>-<index>" and will belong to the group "pool_name".
        def acquire(pool_name, count)
          acquire_group(pool_name)
          uids = acquire_uids(pool_name, count)
          new(pool_name, uids)
        end

        # Deletes all users and groups belonging to +pool_name+.
        def destroy(pool_name)
          find_users(pool_name).each do |user|
            sh "userdel #{user[:user].name}"
          end

          if find_group(pool_name)
            sh "groupdel #{pool_name}"
          end
        end

        def find_group(group_name)
          begin
            Etc.getgrnam(group_name)
          rescue ArgumentError
            # getgrname raises ArgumentError if the group cannot be found
            nil
          end
        end

        def find_users(pool_name)
          users = []
          Etc.passwd do |user|
            match = user.name.match(/^#{pool_name}-(\d+)$/)
            users << {:index => match[1].to_i, :user => user} if match
          end
          users
        end

        private

        # Looks up the group associated with +pool_name+. Creates the group
        # if it does not exist.
        def acquire_group(pool_name)
          group = find_group(pool_name)
          unless group
            debug "Creating group #{pool_name}"
            sh "addgroup --system #{pool_name}"
            group = find_group(pool_name)
          end
          group
        end

        # Returns +count+ uids belonging to +pool_name+. Creates any missing
        # uids.
        def acquire_uids(pool_name, count)
          indices = Set.new((0...count).map {|x| x })
          to_create = indices.dup

          # Find existing
          find_users(pool_name).each do |user|
            to_create.delete(user[:index])
          end

          # Create missing
          to_create.each do |index|
            username = "#{pool_name}-#{index}"
            info "Creating user '#{username}'"
            sh "adduser --system --quiet --no-create-home --home '/nonexistant' #{username}"
            sh "usermod -g #{pool_name} #{username}"
          end

          # Grab uids
          uids = []
          find_users(pool_name).each do |user|
            uids << user[:user].uid if indices.include?(user[:index])
          end

          unless uids.length == count
            raise WardenError, "Unable to acquire all uids"
          end

          uids
        end
      end

      attr_reader :name
      attr_reader :size

      def initialize(name, uids)
        @name  = name
        @uids  = uids
        @size  = uids.length
      end

      # Acquires a user from the pool
      def acquire
        uid = @uids.pop
        if uid.nil?
          raise NoUidAvailable, "no uid available"
        else
          uid
        end
      end

      # Returns a user back to the pool
      def release(uid)
        @uids << uid
      end
    end

  end # Warden::Container
end
