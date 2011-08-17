$:.unshift(File.join(File.dirname(__FILE__),'../../common/lib'))
$:.unshift(File.join(File.dirname(__FILE__)))
require 'vcap/subprocess'
require 'lib/vdebug'
module GemUtil
  class << self
    def run(cmd)
      pdebug "running % #{cmd}}"
      result = VCAP::Subprocess.new.run(cmd)
      pdebug "result:#{result}"
    end

    def gem_to_package(gem_name)
      base_gem,_,_ = gem_name.rpartition('.')
      base_gem + '.tgz'
    end

    def gem_to_url(gem_name)
      "http://production.s3.rubygems.org/gems/#{gem_name}"
    end

    def fetch_remote_gem(gem_name)
      url = gem_to_url(gem_name)
      run("wget --quiet --retry-connrefused --connect-timeout=5 --no-check-certificate #{url}")
    end
  end
end


