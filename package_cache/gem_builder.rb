$:.unshift(File.join(File.dirname(__FILE__)))
require 'tmpdir'
require 'lib/user_ops'
require 'lib/run_as'
require 'gem_util'

class GemBuilder
  def initialize(uid, build_root)
    raise "invalid build_root" if not Dir.exists?(build_root)
    @build_dir = Dir.mktmpdir(nil, build_root)
    @uid = uid
    @gem_name = nil
    @gem_path = nil
    @package_path = nil
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
  end

  def get_package
    raise "No package currently built" if not File.exists?(@package_path)
    @package_path
  end

  def build
    UserOps.init
    install_dir = Dir.mktmpdir(nil, @build_dir)
    UserOps.run_as(@build_dir, @uid, "gem install #{@gem_path} --local --no-rdoc --no-ri -E -w -f --ignore-dependencies --install-dir #{install_dir}")

    package_file = GemUtil.gem_to_package(@gem_name)
    UserOps.run_as(@build_dir, @uid, "tar czf #{package_file} #{install_dir}")
    @package_path = File.join @build_dir, package_file
    raise "Build failed!" if not File.exist? @package_path
  end

  def clean_up!
    FileUtils.rm_rf @build_dir
    @gem_name = @gem_path = @build_dir = @package_path = nil
  end
end
