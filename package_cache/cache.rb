$:.unshift(File.join(File.dirname(__FILE__)))
require 'fileutils'
require 'logger'
require 'lib/vdebug'

module PackageCache
  class Cache
    def initialize(cache_dir, logger = nil)
      @logger = logger ||  Logger.new(STDOUT)
      @cache_dir = cache_dir
      @uid = Process.uid
      @gid = Process.gid
      set_cache_permissions(@cache_dir)
    end

    #XXX this could be prettified with parameter hash so reads add(path, move_method => :rename)
    def add_by_rename!(package_src)
      @logger.debug("starting add #{package_src} to cache.}")
      package_name = File.basename(package_src)
      package_dst = package_name_to_path(package_name)
      if contains?(package_name)
        @logger.debug "package #{package_name} already in cache, won't add."
        return false
      end
      File.rename(package_src, package_dst)
      set_package_permissions(package_dst)
      @logger.debug("package #{package_src} added to cache.}")
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
      @logger.debug("purging cache #{@cache_dir}")
      FileUtils.rm_f Dir.glob("#{@cache_dir}/*")
    end

    private

    def set_cache_permissions(path)
      #raise "package_cache must own its root!" if not File.owned?(path)
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
end

