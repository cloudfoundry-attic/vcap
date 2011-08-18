$:.unshift(File.join(File.dirname(__FILE__)))
require 'fileutils'
require 'logger'
require 'lib/vdebug'

class PackageCache
  def initialize(cache_dir, logger = nil)
    @logger = logger ||  Logger.new(STDOUT)
    @cache_dir = cache_dir
    @uid = Process.uid
    @gid = Process.gid
    set_cache_permissions(@cache_dir)
  end

  def add_by_rename!(package_src)
    package_name = File.basename(package_src)
    package_dst = package_name_to_path(package_name)
    if contains?(package_name)
      @logger.debug "package #{package_name} already in cache, won't add."
      return false
    end
    File.rename(package_src, package_dst)
    set_package_permissions(package_dst)
    true
  end

  def remove!(package_name)
    package_path = package_name_to_path(package_name)
    if not contains?(package_name)
      @logger.debug "package #{package_name} not in cache, can't remove."
      return false
    end
    File.unlink(package_path)
    true
  end

  def contains?(package_name)
    File.exists? package_name_to_path(package_name)
  end

  def purge!
    FileUtils.rm_f Dir.glob("#{@cache_dir}/*")
  end

  private

  def set_cache_permissions(path)
    raise "package_cache must own its root!" if not File.owned?(path)
    #clients can access cache contents, but not list them.
    File.chmod(0711, path)
  end

  #clients should be able read packages
  def set_package_permissions(path)
    File.chown(@uid, @gid, path)
    File.chmod(0744, path)
  end

  def package_name_to_path(package_name)
    File.join @cache_dir, package_name
  end

end

