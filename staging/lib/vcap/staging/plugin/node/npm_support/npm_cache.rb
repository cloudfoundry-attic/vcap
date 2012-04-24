require "fileutils"

class NpmCache
  def initialize(directory, logger)
    @cached_dir  = File.join(directory, "npm_cache")
    @logger = logger
    FileUtils.mkdir_p(@cached_dir)
  end

  def put(source, name, version)
    return unless source && File.exists?(source)
    dir = File.join(@cached_dir, name, version)
    package_path = File.join(dir, "package")
    return if File.exists?(package_path)
    FileUtils.mkdir_p(File.dirname(package_path))
    begin
      File.rename(source, package_path)
    rescue => e
      @logger.debug("Failed putting into cache: #{e}")
      return nil
    end

    package_path
  end

  def get(name, version)
    dir = File.join(@cached_dir, name, version)
    return nil unless File.exists?(File.join(dir, ".done"))
    package_path = File.join(dir, "package")
    return package_path if File.directory?(package_path)
  end
end
