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
  end

  def transfer_ownership(path)
    Run.run_cmd("sudo chown -R +#{@user[:uid]}:+#{@user[:gid]} #{path}")
  end

  def recover_ownership(path)
    Run.run_cmd("sudo chown -R +#{Process.uid}:+#{Process.gid} #{path}")
  end

  def run_restricted(run_dir, user, cmd)
    Dir.chdir(run_dir) {
      run_cmd = "sudo -u #{user[:user_name]} #{cmd} 2>&1"
      transfer_ownership(run_dir)
      stdout = `#{run_cmd}`
      recover_ownership(run_dir)
      status = $?
      return stdout, status
    }
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
