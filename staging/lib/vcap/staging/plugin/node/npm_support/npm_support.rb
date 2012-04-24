require "logger"
require "fileutils"

require File.expand_path('../npm_cache', __FILE__)
require File.expand_path('../npm_package', __FILE__)
require File.expand_path('../npm_helper', __FILE__)

module NpmSupport

  # If there is no dependencies config in package.json don't do anything
  # For each dependency:
  # - Resolve its version (Fail if not possible)
  # - Get from cache by name & version
  # - If not in cache, run npm install, put in cache

  def compile_node_modules
    # npm install support only if dependencies provided in package.json
    @dependencies = get_dependencies
    return unless @dependencies.is_a?(Hash)

    # npm provided?
    return nil unless runtime["npm"]
    @npm_helper = NpmHelper.new(runtime["executable"], runtime["version"], runtime["npm"])
    return unless @npm_helper.npm_version

    @app_dir = File.expand_path(File.join(destination_directory, "app"))
    @app_modules_dir = File.join(@app_dir, "node_modules")

    setup_logger

    cache_base_dir = StagingPlugin.platform_config["cache"]
    cache_dir  = File.join(cache_base_dir, "node_modules", library_version)
    @cache = NpmCache.new(cache_dir, @logger)

    install_packages
  end

  def install_packages
    @logger.info("Installing dependencies. Node version #{runtime["version"]}")
    @dependencies.each do |name, version|
      package = NpmPackage.new(name, version, @app_modules_dir, @staging_uid,
                               @staging_gid, @npm_helper, @logger, @cache)
      package.install
    end
  end

  def get_dependencies
    @package_config["dependencies"] if @package_config.is_a?(Hash)
  end

  def library_version
    environment[:runtime] == "node06" ? "06" : "04"
  end

  def setup_logger
    log_file = File.expand_path(File.join(@app_dir, "..", "logs", "staging.log"))
    FileUtils.mkdir_p(File.dirname(log_file))

    @logger = Logger.new(log_file)
    @logger.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO
    @logger.formatter = lambda { |sev, time, pname, msg| "#{msg}\n" }
  end
end
