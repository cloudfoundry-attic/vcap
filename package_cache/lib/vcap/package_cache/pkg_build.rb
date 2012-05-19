require 'logger'
require 'pkg_util'

module VCAP module PackageCache end end


class VCAP::PackageCache::PkgBuild
  def initialize(buildenv, logger = nil)
    @logger = logger || Logger.new(STDOUT)
    @buildenv = buildenv
    @install_dir = 'install'
    status, out, err = @buildenv.run("mkdir #{@install_dir}")
    raise "install dir create failed" unless status == 0
  end

  def copy_in_pkg_src(path, name)
    @buildenv.copy_in(path, name)
    @src_path = File.join('.', name)
  end

  def copy_out_pkg(src, dst)
    @buildenv.copy_out(src, dst)
  end

  def create_package(name, runtime)
    package_file = PkgUtil.to_package(name, runtime)
    status, out, err = @buildenv.run("cd #{@install_dir} ; tar czf #{package_file} *")
    if status != 0
      raise "tar cf #{package_file} failed> exist status: #{status}, output: #{out + err}"
    end
    package_path = File.join(@install_dir, package_file)
    package_path
  end

  def clean_up!
    @buildenv.destroy!
  end
end

