$:.unshift(File.join(File.dirname(__FILE__)))
require 'sinatra/base'
require 'logger'
require 'loader'

class PackageCacheApi < Sinatra::Base
  def initialize
    super
    @logger = Logger.new(STDOUT)
    @logger.info("Starting up package cache")
    @loader = Loader.new(@logger)
  end

  put '/load/:type/:name' do |type, name|
    if type == 'remote'
      puts type,name
      @loader.load_remote_gem(name)
    elsif type == 'local'
      @loader.load_local_gem(name)
    else
      raise 'invalid type'
    end
  end

end
