require 'bundler/lockfile_parser'
require 'set'
require 'thread'

require 'vcap/package_cache_client/client'

module VCAP
  module Plugins
    module Staging
    end
  end
end

class VCAP::Plugins::Staging::BundleInstaller
  ASSET_DIR             = File.expand_path('../../../../../../assets', __FILE__)
  DEFAULT_CONFIG_PATH   = File.join(ASSET_DIR, 'config.yml')
  BUNDLE_CONFIG_PATH    = File.join(ASSET_DIR, 'bundle_config')

  SUPPORTED_RUNTIMES = Set.new(['ruby18', 'ruby19'])
  LIBRARY_VERSIONS = {
    'ruby19' => '1.9.1',
    'ruby18' => '1.8',
  }

  class << self
    def gem_root_path(app_root, runtime)
      library_version = LIBRARY_VERSIONS[runtime]
      File.join(app_root, 'rubygems', 'ruby', library_version)
    end

    def bundle_path(app_root, runtime)
      library_version = LIBRARY_VERSIONS[runtime]
      File.join(app_root, 'vendor', 'bundle', library_version)
    end
  end

  attr_reader :name
  attr_accessor :logger

  def initialize(config_path=DEFAULT_CONFIG_PATH)
    @name = 'bundle_installer'
    @num_installer_threads = 5
    configure(config_path)
  end

  def configure(config_path)
    config = YAML.load_file(config_path)
    if config['num_installer_threads']
      @num_installer_threads = config['num_installer_threads']
    end
  end

  def framework_plugin?
    false
  end

  # Any ruby runtime we support should be staged
  def should_stage?(app_props)
    SUPPORTED_RUNTIMES.include?(app_props['runtime'])
  end

  def stage(framework_plugin, app_root, actions, app_props)
    runtime = app_props['runtime']

    gemfile_lock_path = File.join(app_root, 'Gemfile.lock')
    bundle_path = self.class.bundle_path(app_root, runtime)
    # Not bundled, or packaged in deployment mode
    if !File.exists?(gemfile_lock_path)
      actions.log.info("No Gemfile.lock found, returning.")
      return
    elsif File.exists?(bundle_path)
      actions.log.info("App was bundled in deployment mode, returning.")
      return
    end

    # Parse/install gems
    deps = parse_lockfile(gemfile_lock_path)
    deps << 'bundler-1.0.10'
    actions.log.info("Parsed Gemfile.lock")
    install_gems(app_root, runtime, deps, actions.log)

    # Remove cached binary .gem files
    gem_cache_path =
      File.join(self.class.gem_root_path(app_root, runtime), "cache")
    FileUtils.rm_rf(gem_cache_path)

    # This sets a relative path to the bundle directory, so nothing is confused
    # after the app is unpacked on a DEA.
    bundle_config_dir = File.join(app_root, '.bundle')
    FileUtils.mkdir_p(bundle_config_dir)
    FileUtils.cp(BUNDLE_CONFIG_PATH, File.join(bundle_config_dir, 'config'))

    library_version = LIBRARY_VERSIONS[app_props['runtime']]
    actions.environment['PATH'] =
      "\"$PWD/app/rubygems/ruby/#{library_version}/bin:$PATH\""
    ['GEM_PATH', 'GEM_HOME'].each do |gem_var|
      actions.environment[gem_var] =
        "\"$PWD/app/rubygems/ruby/#{library_version}\""
    end
  end

  def parse_lockfile(gemfile_lock_path)
    lockfile_contents = File.read(gemfile_lock_path)
    # Bizzare api, but instantiation causes parsing
    parser = Bundler::LockfileParser.new(lockfile_contents)
    parser.specs.map {|spec| "#{spec.name}-#{spec.version}" }
  end

  def install_gems(app_root, runtime, deps, log)
    work_queue = Queue.new
    stop_sentinel = :stop
    deps.each {|dep| work_queue << dep }
    @num_installer_threads.times { work_queue << stop_sentinel }

    # Spin up worker thread pool
    installer_threads = []
    @num_installer_threads.times do
      t = Thread.new do
        client = VCAP::PackageCacheClient::Client.new
        while (dep = work_queue.pop) != stop_sentinel
          log.info("Installing #{dep}")
          install_gem(app_root, dep, runtime, client)
          log.info("Installed #{dep}")
        end
      end
      t.abort_on_exception = true
      installer_threads << t
    end

    installer_threads.each {|t| t.join }
  end

  def install_gem(app_root, gem_name, runtime, client)
    gem_path = nil
    gem_basename = "#{gem_name}.gem"
    vendored_gem_path = File.join(app_root, 'vendor', 'cache', gem_basename)

    if File.exist?(vendored_gem_path)
      # Install vendored gem
      gem_path = client.get_package_path(vendored_gem_path, :local, runtime)
      unless gem_path
        client.add_package(:local, :gem, vendored_gem_path, runtime)
        gem_path = client.get_package_path(vendored_gem_path, :local, runtime)
      end
    else
      # Install from rubygems
      unless gem_path = client.get_package_path(gem_basename, :remote, runtime)
        client.add_package(:remote, :gem, gem_basename, runtime)
        gem_path = client.get_package_path(gem_basename, :remote, runtime)
      end
    end

    unless gem_path
      raise "Failed installing gem #{gem_name}"
    end

    # Copy gem to app
    gem_root_path = self.class.gem_root_path(app_root, runtime)
    FileUtils.mkdir_p(gem_root_path)
    #unless system("cp -a #{gem_path}/* #{gem_root_path}")
    unless system("cd #{gem_root_path} && tar -zxf #{gem_path}")
      raise "Failed copying installed gem to app"
    end
  end
end
