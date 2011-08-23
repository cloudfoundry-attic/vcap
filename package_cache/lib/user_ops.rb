$:.unshift(File.join(File.dirname(__FILE__),'../../common/lib'))
$:.unshift(File.join(File.dirname(__FILE__)))

require 'logger'
require 'vcap/subprocess'

module UserOps
  class << self
    def init(logger = nil)
      @logger = logger || Logger.new(STDOUT)
    end

    def run(cmd)
      #@logger.debug "running >>> #{cmd}}"
      result = VCAP::Subprocess.new.run(cmd)
      #@logger.debug result
    end

    def exists_in_file(name, path)
      File.open(path).each { |line|
        return true if line =~ Regexp.new("^#{name}:")
      }
      false
    end

    def name_to_id(name, path)
      File.open(path).each { |line|
          name_field,_,id = line.split(':')
          return id if name == name_field
      }
      raise "invalid name"
    end

    def name_to_entry(name, path)
      File.open(path).each { |line|
          name_field,_ = line.split(':')
          return line if name == name_field
      }
      raise "invalid name"
    end

    ##groups
    def group_to_gid(group_name)
      _,_,id = name_to_entry(group_name, '/etc/group').split(':')
      id
    end

    def group_exists?(group_name)
      exists_in_file(group_name, '/etc/group')
    end

    def install_group(group_name)
      run("addgroup --system #{group_name}")
    end

    def remove_group(group_name)
      run("delgroup --system #{group_name}")
    end

    #XXX better error handling
    def group_kill_all_procs(group_name)
      begin
      run("pkill -9 -G #{group_name}")
      #rescue VCAP::SubprocessStatusError => e
      rescue => e
        @logger.debug "ignoring"
      end
    end

   ##users
    def user_to_uid(user_name)
      _,_,id = name_to_entry(user_name, '/etc/passwd').split(':')
      id
    end

    def user_to_gid(user_name)
      _,_,_,id = name_to_entry(user_name, '/etc/passwd').split(':')
      id
    end

    def user_exists?(user_name)
      exists_in_file(user_name, '/etc/passwd')
    end

    #XXX better error handling
    def user_kill_all_procs(user_name)
      begin
      run("pkill -9 -u #{user_name} 2>&1")
      #rescue VCAP::SubprocessStatusError => e
      #  @logger.debug e.exit_status
      rescue => e
        @logger.debug "ignoring"
      end
    end

    def install_user(user_name, group_name, uid)
      run("adduser --system --quiet --no-create-home --home '/nonexistent' --uid #{uid} #{user_name}")
      run("usermod -g #{group_name} #{user_name}")
    end

    def remove_user(user_name)
      run("deluser #{user_name}")
    end
  end
end


