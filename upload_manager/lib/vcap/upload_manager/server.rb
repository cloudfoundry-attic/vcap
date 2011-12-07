require 'rubygems'
require 'sinatra'
require 'filesystem_pool'
require 'app_packer'
require 'package_store'
require 'yajl'

module VCAP module UploadManager end end

class VCAP::UploadManager::UploadManagerServer < Sinatra::Base
  RESOURCE_LIST_MAX = 1024

  def initialize(server_params)
    super
    @logger = server_params[:logger]
    @directories = server_params[:directories]
    @config = server_params[:config]
    @logger.info("Initializing server...")
    init_components
  end

  def init_components
    pool_dir = @directories['resource_pool']
    @resource_pool = VCAP::UploadManager::FilesystemPool.new(pool_dir, @logger)

    store_dir = @directories['package_store']
    @package_store = VCAP::UploadManager::PackageStore.new(store_dir, @logger)
  end

  def parse_resource_list(message)
    result = Yajl::Parser.parse(message, :symbolize_keys => true) || []
    raise "invalid type" unless Array === result
    raise "resource list exceeds max size" if result.size > RESOURCE_LIST_MAX
    result
  end

  def dummy_auth_check
    @logger.debug "dummy auth check"
  end

  before do
    dummy_auth_check
  end

  get '/uploads/resources' do
    resource_list = parse_resource_list(params[:content])
    matches = @resource_pool.match_resources(resource_list)
    body = Yajl::Encoder.encode(matches)
  end

  post '/uploads/:storageid/application' do |storageid|
    if params[:application] && params[:application][:tempfile]
      upload_path = params[:application][:tempfile]
      resource_list = parse_resource_list(params[:resources])
      #XXX make sure we check the size of the file upload.
      #XXX this should be enforced by nginx as well.
      #XXX add general error handling, after nginx support.
      begin
        packer_dir = @directories['app_packer']
        packer = VCAP::UploadManager::AppPacker.new(packer_dir, @resource_pool, @logger)
        packer.import_upload(storageid, upload_path, resource_list)
        packer.package_app
        package_path = packer.get_package
        @package_store.put_package(storageid, package_path)
        status(200)
      ensure
        packer.cleanup!
      end
    else
      status(400)
      content_type(:text)
      "Missing application body"
    end
  end

  get '/uploads/:storageid/application' do |storageid|
    if @package_store.contains?(storageid)
      send_file(@package_store.get_package_path(storageid))
    else
      error(404)
    end
  end

end

