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
    #make config use optional, no config for unit testing.
    if server_params[:config]
      @config = server_params[:config]
      @use_nginx = server_params[:config][:nginx][:use_nginx]
    else
      @use_nginx = false
    end
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

  get '/resources' do
    resource_list = parse_resource_list(params[:content])
    matches = @resource_pool.match_resources(resource_list)
    body = Yajl::Encoder.encode(matches)
  end

  def store_upload(storageid, upload_path, resource_list)
    @logger.debug("upload request: id: #{storageid}, path: #{upload_path}, resources: #{resource_list.to_s}")
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
      FileUtils.rm_f upload_path
    end
  end

  post '/upload/:storageid' do |storageid|
    #XXX add some error handling to make sure these fields are present
    #if needed -- need to think about this, could support empty
    #upload file and resource list, or one or the other or both,
    #need to make sure to test this end-2-end.
    #XXX add a check for file uploaded file size.
    #XXX add some error handling.
    if @use_nginx
      upload_path = params[:application_path]
    else
      upload_path = params[:application][:tempfile]
    end
    resource_list = parse_resource_list(params[:resources])
    store_upload(storageid, upload_path, resource_list)
  end

  get '/download/:storageid' do |storageid|
    if @package_store.contains?(storageid)
      if @use_nginx
        status(200)
        content_type "application/octet-stream"
        response["X-Accel-Redirect"] = "/package_store/#{storageid}.zip"
      else
        package_path = @package_store.get_package_path(storageid)
        send_file(package_path)
      end
    else
      error(404)
    end
  end

end

