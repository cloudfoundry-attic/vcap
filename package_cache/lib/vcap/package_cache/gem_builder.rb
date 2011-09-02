$:.unshift(File.join(File.dirname(__FILE__)))
require 'tmpdir'
require 'lib/user_ops'
require 'lib/run_as'
require 'gem_util'
require 'lib/vdebug'
require 'lib/emrun'

module VCAP module PackageCache end end

#XXX cleanup references to @uid/@gid
class VCAP::PackageCache::GemBuilder
  def initialize(user, build_root, logger = nil)
    raise "invalid build_root" if not Dir.exists?(build_root)
    @logger = logger || Logger.new(STDOUT)
    @build_dir = Dir.mktmpdir(nil, build_root)
    @user = user
    @uid = user[:uid]
    @gid = user[:gid]
    @gem_name = nil
    @gem_path = nil
    @package_path = nil
    @logger.debug("new gem_builder with uid: #{@uid} build_root #{build_root}")
    VCAP::EMRun.init(@logger)
  end

  #XXX using a parameter hash could prettify this.
  def import_gem(gem_src, import_method = nil)
    raise "invalid path #{gem_src}" if not File.exists?(gem_src)
    @gem_name = File.basename(gem_src)
    @gem_path = File.join(@build_dir, @gem_name)
    if import_method == :rename
      File.rename(gem_src, @gem_path)
    else
      FileUtils.cp(gem_src, @gem_path)
    end
    File.chown(@uid, nil, @gem_path)
    @logger.debug("successfully imported #{@gem_name}")
  end

  def get_package
    raise "No package currently built" if not File.exists?(@package_path)
    @package_path
  end

  def grant_permission(path)
    File.chown(@uid, @gid, path)
    File.chmod(0700, path)
  end

  def build
    @logger.info("building gem #{@gem_path}")

    install_dir = Dir.mktmpdir(nil, @build_dir)

    @logger.debug("granting #{@uid} access to build resources")
    grant_permission(@build_dir)
    grant_permission(@gem_path)
    grant_permission(install_dir)

    output, status = VCAP::EMRun.run_restricted(@build_dir, @user,
        "gem install #{@gem_path} --local --no-rdoc --no-ri -E -w -f --ignore-dependencies --install-dir #{install_dir}")

    if status != 0
      @logger.debug("gem install #{@gem_path} failed \n <<<BEGIN ERROR OUTPUT>>>: #{output} <<<END ERROR OUTPUT>>>")
      raise "gem install #{@gem_name} failed, exist status: #{status} (enable debug logging for details)."
    end

    raise "gem install failed!" if not File.exist? File.join(install_dir, 'gems')
    @logger.debug("gem install of #{@gem_path} to #{install_dir} complete.")

    package_file = GemUtil.gem_to_package(@gem_name)
    output, status = VCAP::EMRun.run_restricted(install_dir, @user,
                                           "tar czf #{package_file} gems")
    if status != 0
      raise "tar czf #{package_file} failed> exist status: #{status}, output: #{output}"
    end

    @package_path = File.join(install_dir, package_file)
    raise "package build failed!" if not File.exist? @package_path
    @logger.debug("created package #{@package_path}.")
  end

  def clean_up!
    FileUtils.rm_rf @build_dir
    @gem_name = @gem_path = @build_dir = @package_path = nil
  end
end
