
require 'logger'

module VCAP module UploadManager end end

class VCAP::UploadManager::PackageStore
  def initialize(store_dir, logger = nil)
    @logger = logger || Logger.new(STDOUT)
    raise "invalid package dir" unless Dir.exists? store_dir
    @store_dir = store_dir
    @logger.debug("initialized package store with dir #{store_dir}")
  end

  def put_package(id, src_path)
    @logger.debug("putting package #{id} into store")
    @logger.debug("overwriting existing package #{id}") if contains?(id)
    FileUtils.cp(src_path, package_path(id))
  end

  def get_package_path(id)
    package_path(id)
  end

  def contains?(id)
    File.exists? package_path(id)
  end

  def cleanup!
    FileUtils.rm_rf @store_dir, :secure => true
  end

  private

  def package_path(id)
    package_name = "#{id}.zip"
    File.join(@store_dir, package_name)
  end

end
