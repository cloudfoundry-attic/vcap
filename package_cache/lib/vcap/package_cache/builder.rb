require 'tmpdir'
require 'logger'
require 'run'

module VCAP module PackageCache end end

class VCAP::PackageCache::Builder
  def initialize(user, build_root, runtimes, logger = nil)
    raise "invalid build_root" if not Dir.exists?(build_root)
    @logger = logger || Logger.new(STDOUT)
    @user = user
    @runtimes = runtimes
    @build_dir = Dir.mktmpdir(nil, build_root)
    @package_path = nil
    Run.init(@logger)
  end

  def import_package_src(package_src)
    raise "invalid path #{package_src}" if not File.exists?(package_src)
    @src_name = File.basename(package_src)
    @src_path = File.join(@build_dir, @src_name)
    File.rename(package_src, @src_path)
    @logger.debug("successfully imported #{@src_name}")
  end

  def get_package
    raise "No package currently built" if not File.exists?(@package_path)
    @package_path
  end

  def build(location, name, path = nil)
    raise "method not implemented!!"
  end

  def clean_up!
    @logger.debug("cleaning up #{@build_dir}")
    FileUtils.rm_rf @build_dir
  end
end
