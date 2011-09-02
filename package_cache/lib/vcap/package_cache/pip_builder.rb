require 'tmpdir'

require 'lib/user_ops'
require 'lib/emrun'

require 'builder'
require 'pkg_util'


module VCAP module PackageCache end end

class VCAP::PackageCache::PipBuilder < VCAP::PackageCache::Builder
    def pip_to_archive(name)
      PkgUtil.drop_extension(name) + '.tar.bz2'
    end

   def setup_build
    output, status = VCAP::EMRun.run_restricted(@build_dir, @user,
                                                "virtualenv INSTALL_DIR")
    if status != 0
      @logger.debug("XXX add more stuff failed")
    end

    @pip_path = File.join(File.dirname(@src_path), pip_to_archive(@src_name))
    File.rename(@src_path, @pip_path)
    @logger.debug("#{@src_path} renamed to => #{@pip_path}")
  end

  def build_pip
    output, status = VCAP::EMRun.run_restricted(@build_dir, @user,
         "./INSTALL_DIR/bin/pip install #{@pip_path}")

     if status != 0
       @logger.debug("pip install failed...!!! XXX add more")
     end
  end

  def package_pip
    base_name = PkgUtil.drop_extension(@src_name)
    package_file = PkgUtil.to_package(@src_name)
    package_dir = File.join @build_dir, "INSTALL_DIR/lib/python2.6/site-packages/#{base_name}-py2.6.egg-info"
    package_manifest = 'installed-files.txt'
    output, status = VCAP::EMRun.run_restricted(package_dir, @user,
                                           "tar czf #{package_file} --files-from=#{package_manifest}")
    if status != 0
      raise "tar czf #{package_file} failed> exist status: #{status}, output: #{output}"
    end
    package_path = File.join(package_dir, package_file)
    raise "package build failed!" if not File.exist? package_path
    package_path
  end

  def build
    @logger.info("building package #{@src_path}")
    setup_build
    build_pip
    @package_path = package_pip
  end
end


