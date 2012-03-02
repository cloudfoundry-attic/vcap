require "fileutils"

class NpmCache
  def initialize(directory)
    @cached_dir  = File.join(directory, "npm_cache")
    FileUtils.mkdir_p(@cached_dir)
  end

  def put(source, name, version)
    return unless source && File.exists?(source)
    dir = File.join(@cached_dir, name, version)
    package_path = File.join(dir, "package")
    FileUtils.mkdir_p(package_path)

    `cp -n #{source}/package.json #{package_path}`
    # Someone else is copying package?
    return source if $?.exitstatus != 0

    `cp -a #{source}/* #{package_path} && touch #{dir}/.done`
    return source if $?.exitstatus != 0

    package_path
  end

  def get(name, version)
    dir = File.join(@cached_dir, name, version)
    return nil unless File.exists?(File.join(dir, ".done"))
    package_path = File.join(dir, "package")
    return package_path if File.directory?(package_path)
  end
end
