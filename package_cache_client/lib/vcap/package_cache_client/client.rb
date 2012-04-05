$:.unshift(File.dirname(__FILE__))
require 'rest-client'
require 'logger'

require 'inbox_client'
require 'cache_client'
require 'config'
require 'errors'
require 'pkg_util'

module VCAP module PackageCacheClient end end

class VCAP::PackageCacheClient::Client
  def initialize(logger = nil)
    @logger = logger || Logger.new(STDOUT)
    config_file = VCAP::PackageCacheClient::Config::DEFAULT_CONFIG_PATH
    config = VCAP::PackageCacheClient::Config.from_file(config_file)
    setup_client(config)
  end

  def setup_client(config)
    #XXX validate that end-point exists and we can connect to it.
    @cache_addr = "127.0.0.1:#{config[:listen_port]}"
    base_dir =  config[:base_dir]
    cache_dir = File.join base_dir,'cache'
    inbox_dir = File.join base_dir,'inbox'
    @inbox = VCAP::PackageCacheClient::InboxClient.new(inbox_dir, @logger)
    @cache_client = VCAP::PackageCacheClient::CacheClient.new(cache_dir, @logger)
    @logger.info("setup package cache client on #{@cache_addr}: #{inbox_dir}")
  end

  def add_package(location, type, id, runtime)
    begin
      if location == :remote
        name = id
        response = RestClient.put "#{@cache_addr}/load/remote/#{type}/#{name}/#{runtime}",''
      elsif location == :local
        path = id
        raise "invalid path" if not File.exist?(path)
        entry_name = @inbox.add_entry(path)
        response = RestClient.put "#{@cache_addr}/load/local/#{type}/#{entry_name}/#{runtime}",''
      else
        raise VCAP::PackageCacheClient::ClientError.new("invalid location")
      end
    rescue => e
      @logger.error "PackageCacheClient Error."
      if e.respond_to?('response')
        raise VCAP::PackageCacheClient::ServerError.new(e.response)
      end
      @logger.error e.message
      @logger.error e.backtrace.join("\n")
    end
  end

  #XXX seems like file_to_entry_name should be renamed to reflect its
  #XXX function more clearly.
  def get_package_path(gem_path, location, runtime)
    if location == :remote
      gem_name = File.basename(gem_path)
    elsif location == :local
       gem_name = @inbox.file_to_entry_name(gem_path)
    else
      raise "invalid package location"
    end
    package_name = PkgUtil.to_package(gem_name, runtime)
    @cache_client.get_package_path(package_name)
  end
end

