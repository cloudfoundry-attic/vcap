$:.unshift(File.join(File.dirname(__FILE__),'../../common/lib'))
$:.unshift(File.join(File.dirname(__FILE__)))

require 'logger'
require 'fileutils'
require 'vcap/subprocess'
require 'tmpdir'
require 'digest/sha1'
require 'pp'
require 'lib/vdebug'


class Loader

  def initialize(logger = nil)
    @logger = logger ||  Logger.new(STDOUT)
    @cache_root = '/var/vcap.local/package_cache'

    if not Dir.exists?(@cache_root)
      FileUtils.mkdir_p(@cache_root)
      FileUtils.mkdir_p(File.join @cache_root, 'local')
      FileUtils.mkdir_p(File.join @cache_root, 'remote')
    end
  end

  def run(cmd)
    @logger.debug "running % #{cmd}}"
    result = VCAP::Subprocess.new.run(cmd)
    @logger.debug result
  end

  def gem_to_package(base_gem)
    gem_name,_,_ = base_gem.rpartition('.')
    gem_name + '.tgz'
  end

  def gem_to_url(base_gem)
    "http://production.s3.rubygems.org/gems/#{base_gem}"
  end

  def fetch_remote_gem(base_gem)
    url = gem_to_url(base_gem)
    run("wget --quiet --retry-connrefused --connect-timeout=5 --no-check-certificate #{url}")
  end

  def add_to_cache(type, package_path, package_name)
    #XXX add log message
    FileUtils.mv(package_path, File.join(@cache_root, type))
  end

  def load_remote_gem(base_gem)
    #XXX add log message
    gem_path = File.join(Dir.pwd, base_gem)
    fetch_remote_gem(base_gem)
    load_gem('remote', base_gem, gem_path)
  end

  def load_local_gem(base_gem)
    #copy gem from inbox
    #verify hash
    #build_package
    #add_to_cache
  end

  def load_gem(type, base_gem, gem_path)
    package_name = gem_to_package(base_gem)
    package_path = File.join(Dir.pwd, package_name)
    build_package(base_gem, gem_path)
    add_to_cache(type, package_path, package_name)
  end

  def build_package(base_gem, gem_path)
    begin
      package_name = gem_to_package(base_gem)
      package_file = package_name
      install_dir = Dir.mktmpdir
      run("gem install #{gem_path} --local --no-rdoc --no-ri -E -w -f --ignore-dependencies --install-dir #{install_dir}")
      run("tar czf #{package_file} #{install_dir}")
    ensure
      FileUtils.rm_rf(install_dir)
      FileUtils.rm_rf(gem_path)
    end
  end
end


#notes
#sha1 = Digest::SHA1.file(path).hexdigest
