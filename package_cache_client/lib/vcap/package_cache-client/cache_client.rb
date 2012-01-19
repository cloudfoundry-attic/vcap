require 'fileutils'

module VCAP module PackageCacheClient end end

class VCAP::PackageCacheClient::CacheClient
  def initialize(cache_dir, logger = nil)
    @logger = logger ||  Logger.new(STDOUT)
    @cache_dir = cache_dir
  end

  def get_package_path(package_name)
    return nil if not contains?(package_name)
    package_name_to_path(package_name)
  end

  def contains?(package_name)
    File.exists? package_name_to_path(package_name)
  end

  private

  def package_name_to_path(package_name)
    File.join @cache_dir, package_name
  end

end

