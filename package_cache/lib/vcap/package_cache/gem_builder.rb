require 'tmpdir'

require 'lib/user_ops'
require 'lib/emrun'

require 'pkg_util'
require 'builder'

module VCAP module PackageCache end end

class VCAP::PackageCache::GemBuilder < VCAP::PackageCache::Builder
  def setup_build
    @install_dir = Dir.mktmpdir(nil, @build_dir)
    grant_ownership(@install_dir)
  end

  def build_gem(gem_name, gem_path)
    output, status = VCAP::EMRun.run_restricted(@build_dir, @user,
        "gem install #{gem_path} --local --no-rdoc --no-ri -E -w -f --ignore-dependencies --install-dir #{@install_dir}")

    if status != 0
      @logger.debug("gem install #{gem_path} failed \n <<<BEGIN ERROR OUTPUT>>>: #{output} <<<END ERROR OUTPUT>>>")
      raise "gem install #{gem_name} failed, exist status: #{status} (enable debug logging for details)."
    end

    raise "gem install failed!" if not File.exist? File.join(@install_dir, 'gems')
    @logger.debug("gem install of #{gem_path} to #{@install_dir} complete.")
  end

  def package_gem(gem_name)
    package_file = PkgUtil.to_package(gem_name)
    output, status = VCAP::EMRun.run_restricted(@install_dir, @user,
                                           "tar czf #{package_file} gems")
    if status != 0
      raise "tar czf #{package_file} failed> exist status: #{status}, output: #{output}"
    end
    package_path = File.join(@install_dir, package_file)
    raise "package build failed!" if not File.exist? package_path
    package_path
  end

  def build
    @logger.info("building package #{@src_path}")
    setup_build
    build_gem(@src_name, @src_path)
    @package_path = package_gem(@src_name)
    @logger.debug("created package #{@package_path}.")
  end
end
