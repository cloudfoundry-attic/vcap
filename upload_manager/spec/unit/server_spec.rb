$:.unshift(File.dirname(__FILE__))

require 'spec_helper'
require 'fileutils'
require 'server'
require 'upload_manager'
require 'logger'
require 'debug_formatter'
require 'filesystem_pool'
require 'yajl'

require 'rubygems'
require 'rack/test'
ENV["RACK_ENV"] = "test"



describe VCAP::UploadManager::UploadManagerServer do

  include Rack::Test::Methods

  before(:all) do
    enter_test_root
    logger = Logger.new(STDOUT)
    logger.formatter = DebugFormatter.new
    @directories = VCAP::UploadManager.setup_directories('.', logger)
    server_params = { :config => nil,
                      :directories => @directories,
                      :logger => logger}
    @server = VCAP::UploadManager::UploadManagerServer.new(server_params)
    @test_upload_zip = '../fixtures/test_upload.zip'
    @test_upload_file = '../fixtures/test.txt'
    @file_pool = VCAP::UploadManager::FilesystemPool.new(@directories['resource_pool'])
    @upload_id = '1234'
  end

  after(:all) do
    exit_test_root
  end

  #used by Rack::Test
  def app
    @server
  end

  it "should upload a test zip file" do
    post "/uploads/#{@upload_id}/application",
        {"application" => Rack::Test::UploadedFile.new(@test_upload_zip, 'application/zip'), 
         "resources" => nil}
    last_response.status.should == 200
  end

  it "query resource pool for test uploaded file" do
    desc = @file_pool.file_to_descriptor(@test_upload_file)
    resource_list = Yajl::Encoder.encode([desc])
    get '/uploads/resources', { :content => resource_list}
    last_response.status.should == 200
    last_response.body.should == resource_list
  end

  it "download an application" do
    get "/uploads/#{@upload_id}/application"
    last_response.status.should == 200
  end

end
