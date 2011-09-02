$:.unshift(File.join(File.dirname(__FILE__),'../../common/lib'))
$:.unshift(File.join(File.dirname(__FILE__)))

require 'logger'
require 'vcap/subprocess'
require 'vdebug'

module UserOps
  class << self
    def run(cmd, expected_exit_status = 0)
      #pdebug "running >>> #{cmd}}"
      result = VCAP::Subprocess.run(cmd, expected_exit_status)
      #pdebug "run result: #{result}"
    end

    def group_exists?(name)
      found = false
      Etc.group { |g| found = true if g.name == name}
      Etc.endgrent
      found
    end

    def install_group(group_name)
      run("addgroup --system #{group_name}")
    end

    def remove_group(group_name)
      run("delgroup --system #{group_name}")
    end

    def user_exists?(name)
      found = false
      Etc.passwd { |u| found = true if u.name == name}
      Etc.endpwent
      found
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
