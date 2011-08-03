require 'resque'
require 'sinatra/base'
require 'spec_helper'

require 'vcap/spec/forked_component/nats_server'

# Simple handler that serves zipped apps from the fixtures directory and
# handles uploads by storing the request body in a user supplied hash
class DummyHandler < Sinatra::Base
  use Rack::Auth::Basic do |user, pass|
    user == 'foo' && pass = 'sekret'
  end

  get '/zipped_apps/:name' do
    app_zip_path = File.join(settings.download_path, "#{params[:name]}.zip")
    if File.exist?(app_zip_path)
      File.read(app_zip_path)
    else
      [404, ":("]
    end
  end

  put '/droplets/:name' do
    dest_path = File.join(settings.upload_path, params[:name] + '.tgz')
    File.open(dest_path, 'w+') {|f| f.write(request.body.read) }
    [200, "Success!"]
  end

  get '/fail' do
    [500, "Oh noes"]
  end
end

describe VCAP::Stager do
  before :all do
    # Set this to true if you want to save the output of each component
    @save_logs = false
    @app_props = {
      'framework'   => 'sinatra',
      'runtime'     => 'ruby18',
      'services'    => [{}],
      'resources'   => {
        'memory'    => 128,
        'disk'      => 1024,
        'fds'       => 64,
      },
    }
  end

  before :each do
    @tmp_dirs     = create_tmp_dirs
    @uploads      = {}
    @http_server  = start_http_server(@tmp_dirs[:upload], @tmp_dirs[:download], @tmp_dirs[:http])
    @http_port    = @http_server.port
    @redis_server = start_redis(@tmp_dirs[:redis])
    @nats_server  = start_nats(@tmp_dirs[:nats])
    @stager       = start_stager(@redis_server.port,
                                 @nats_server.port,
                                 StagingPlugin.manifest_root,
                                 @tmp_dirs[:stager])
  end

  after :each do
    @stager.stop
    @redis_server.stop
    @http_server.stop
    @nats_server.stop
    if @save_logs
      puts "Logs saved under #{@tmp_dirs[:base]}"
    else
      FileUtils.rm_rf(@tmp_dirs[:base])
    end
  end

  describe 'on success' do
    it 'it should post a bundled droplet to the callback uri' do
      app_id   = 'zazzle'
      app_name = 'sinatra_gemfile'
      dl_uri   = app_download_uri(app_name)
      ul_uri   = droplet_upload_uri(app_name)
      subj     = 'staging.result'
      zip_app(@tmp_dirs[:download], app_name)

      # Wait for the stager to tell us it is done
      task_result = wait_for_task_result(@nats_server.uri,
                                         @redis_server.port,
                                         subj,
                                         [app_id, @app_props, dl_uri, ul_uri, subj])
      task_result.should_not be_nil
      task_result.was_success?.should be_true

      # Check result in redis
      result = VCAP::Stager::TaskResult.fetch(app_id, Redis.new(:host => '127.0.0.1', :port => @redis_server.port))
      result.should_not be_nil
      result.was_success?.should be_true
    end
  end

  def create_tmp_dirs
    tmp_dirs = {:base => Dir.mktmpdir}
    for d in [:upload, :download, :redis, :nats, :stager, :http]
      tmp_dirs[d] = File.join(tmp_dirs[:base], d.to_s)
      Dir.mkdir(tmp_dirs[d])
    end
    tmp_dirs
  end

  def zip_app(dir, app_name)
    app_source_dir = fixture_path('apps', app_name, 'source')
    target_path = File.join(dir, "#{app_name}.zip")
    VCAP::Subprocess.run("cd #{app_source_dir}; zip -q -y #{target_path} -r *")
    target_path
  end

  def start_http_server(upload_path, download_path, http_dir)
    port = VCAP.grab_ephemeral_port
    DummyHandler.set(:upload_path, upload_path)
    DummyHandler.set(:download_path, download_path)
    http_server = VCAP::Stager::Spec::ForkedHttpServer.new(DummyHandler, port, http_dir)
    http_server.start.wait_ready.should be_true
    http_server
  end

  def start_redis(redis_dir)
    # XXX - Should this come from a config?
    redis_path = `which redis-server`.chomp
    redis_path.should_not == ''
    port = VCAP.grab_ephemeral_port
    redis = VCAP::Stager::Spec::ForkedRedisServer.new(redis_path, port, redis_dir)
    redis.start.wait_ready.should be_true
    redis
  end

  def start_nats(nats_dir)
    port = VCAP.grab_ephemeral_port
    pid_file = File.join(nats_dir, 'nats.pid')
    nats = VCAP::Spec::ForkedComponent::NatsServer.new(pid_file, port, nats_dir)
    nats.start.wait_ready.should be_true
    nats
  end

  def start_stager(redis_port, nats_port, manifest_dir, stager_dir)
    stager = VCAP::Stager::Spec::ForkedStager.new(redis_port, nats_port, manifest_dir, stager_dir)
    stager.start.wait_ready.should be_true
    stager
  end

  def wait_for_task_result(nats_uri, redis_port, subj, task_args)
    task_result = nil
    NATS.start(:uri => nats_uri) do
      EM.add_timer(30) { NATS.stop }
      NATS.subscribe(subj) do |msg|
        task_result = VCAP::Stager::TaskResult.decode(msg)
        NATS.stop
      end
      Resque.redis = Redis.new(:host => '127.0.0.1', :port => redis_port)
      Resque.enqueue(VCAP::Stager::Task, *task_args)
    end
    task_result
  end

  def app_download_uri(app_name)
    "http://foo:sekret@127.0.0.1:#{@http_port}/zipped_apps/#{app_name}"
  end

  def droplet_upload_uri(app_name)
    "http://foo:sekret@127.0.0.1:#{@http_port}/droplets/#{app_name}"
  end
end
