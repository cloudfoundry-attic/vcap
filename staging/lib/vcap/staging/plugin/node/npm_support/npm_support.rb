require "logger"
require "fileutils"

require File.expand_path("../npm_cache", __FILE__)
require File.expand_path("../npm_package", __FILE__)
require File.expand_path("../npm_helper", __FILE__)

module NpmSupport

  # If there is no npm-shwrinkwrap.json file don't do anything
  # If user has node_modules folder and config option "ignoreNodeModules"
  # in cloudfoundry.json is not set don't do anything
  # Otherwise, install node modules according to shwrinkwrap.json tree
  #
  # For each dependency in shrinkwrap tree recursively:
  # - Get from cache by name & version
  # - If not in cache, fetch it, run npm rebuild, put in cache

  def compile_node_modules
    # npm provided?
    return unless runtime["npm"]

    @dependencies = get_dependencies
    return unless should_install_packages?

    @npm_helper = NpmHelper.new(runtime["executable"], runtime["version"], runtime["npm"],
                                @secure_uid, @secure_gid)
    return unless @npm_helper.npm_version

    @app_dir = File.expand_path(File.join(destination_directory, "app"))

    setup_logger

    cache_base_dir = StagingPlugin.platform_config["cache"]
    cache_dir  = File.join(cache_base_dir, "node_modules", library_version)
    @cache = NpmCache.new(cache_dir, @logger)

    @logger.info("Installing dependencies. Node version #{runtime["version"]}")
    install_packages(@dependencies, @app_dir)
  end

  def should_install_packages?
    return unless @dependencies

    return true if @vcap_config["ignoreNodeModules"]

    user_packages_dir = File.join(destination_directory, "app", "node_modules")
    !File.exists?(user_packages_dir)
  end

  def install_packages(dependencies, where)
    dependencies.each do |name, props|
      package = NpmPackage.new(name, props["version"], where, @staging_uid,
                               @staging_gid, @npm_helper, @logger, @cache)
      installed_dir = package.install
      if installed_dir && props["dependencies"].is_a?(Hash)
        install_packages(props["dependencies"], installed_dir)
      end
    end
  end

  def get_dependencies
    shrinkwrap_file = File.join(destination_directory, "app", "npm-shrinkwrap.json")
    return unless File.exists?(shrinkwrap_file)
    shrinkwrap_config = Yajl::Parser.parse(File.new(shrinkwrap_file, "r"))
    if shrinkwrap_config.is_a?(Hash) && shrinkwrap_config["dependencies"].is_a?(Hash)
      shrinkwrap_config["dependencies"]
    end
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
