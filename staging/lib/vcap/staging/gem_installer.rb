require "vcap/concurrency"
require "vcap/package_cache_client/client"

class GemInstaller
  class Error < StandardError; end

  RUNTIME_TO_VERSION = {
    "ruby18" => "1.8",
    "ruby19" => "1.9.1",
  }

  # @param [Hash] client_config  Package cache client config
  # @param [Logger] logger       Ruby-logger compatible logger
  # @param [Hash] opts
  # @option opts [Integer] :num_threads  Number of concurrent threads accessing
  #                                      the package cache
  def initialize(package_cache_config, logger, opts = {})
    @package_cache_config = package_cache_config
    @logger = VCAP::Concurrency::Proxy.new(logger)
    @num_threads = opts[:num_threads] || 2
  end

  # Installs gems using the package cache into the given app directory.
  #
  # @param [Array<[String, String]>] gems  List of gems in form [name, version]
  # @param [String] app_root  The application root
  # @param [String] runtime  CF Specific runtime name
  #
  # @return nil
  def install_gems(gems, app_root, runtime)
    ruby_version = RUNTIME_TO_VERSION[runtime]

    if ruby_version.nil?
      raise GemInstaller::Error.new("Unknown runtime: #{runtime}")
    end

    worker_pool = VCAP::Concurrency::ThreadPool.new(@num_threads)

    promises = gems.map do |name, version|
      @logger.info("Need to install #{name} #{version}")
      worker_pool.enqueue { install_gem(app_root, name, version, runtime) }
    end

    worker_pool.start

    # Wait for the work to finish
    promises.each { |p| p.resolve }

    worker_pool.shutdown

    nil
  end

  private

  def gem_root_path(app_root, ruby_version)
    File.join(app_root, 'rubygems', 'ruby', RUNTIME_TO_VERSION[ruby_version])
  end

  def install_gem(app_root, name, version, runtime)
    client = VCAP::PackageCacheClient::Client.new(@client_config)

    gem_path = nil
    gem_basename = "#{name}-#{version}.gem"
    vendored_gem_path = File.join(app_root, 'vendor', 'cache', gem_basename)

    if File.exist?(vendored_gem_path)
      @logger.info("Found #{name}-#{version} in vendor/cache")

      # Install vendored gem
      gem_path = client.get_package_path(vendored_gem_path, :local, runtime)

      puts "gem_path: #{gem_path}"
      unless gem_path
        # Doesn't exist in cache, ask for it to be installed.
        client.add_package(:local, :gem, vendored_gem_path, runtime)
        gem_path = client.get_package_path(vendored_gem_path, :local, runtime)
      end
    else
      @logger.info("Need to fetch #{name}-#{version} from RubyGems")

      # Install from rubygems
      gem_path = client.get_package_path(gem_basename, :remote, runtime)
      unless gem_path
        client.add_package(:remote, :gem, gem_basename, runtime)
        gem_path = client.get_package_path(gem_basename, :remote, runtime)
      end
    end

    unless gem_path
      raise GemInstaller::Error.new("Failed installing gem #{name}-#{version}")
    end

    # Copy gem to app
    gem_root = gem_root_path(app_root, runtime)
    FileUtils.mkdir_p(gem_root)
    unless system("cd #{gem_root} && tar -xf #{gem_path}")
      raise GemInstaller::Error.new("Failed copying installed gem to app")
    end
  end
end
