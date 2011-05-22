# Copyright (c) 2009-2011 VMware, Inc.
$:.unshift(File.dirname(__FILE__))

require 'spec_helper'

require 'digest/sha1'
require 'fileutils'
require 'nats/client'
require 'uri'
require 'vcap/common'
require 'yaml'

describe 'DEA Agent' do
  nats_timeout_path = File.expand_path(File.join(File.dirname(__FILE__), 'nats_timeout'))
  dea_path = File.expand_path(File.join(__FILE__, "../../../bin/dea"))
  run_id_ctr = 0

  before :all do
    # Base test directory to house invididual run directories
    @test_dir = "/tmp/dea_agent_tests_#{Process.pid}_#{Time.now.to_i}"
    FileUtils.mkdir(@test_dir)
    File.directory?(@test_dir).should be_true

    @tcpserver_droplet_bundle = File.join(@test_dir, 'droplet')
    create_droplet_bundle(@test_dir, @tcpserver_droplet_bundle)
    @droplet = droplet_for_bundle(@tcpserver_droplet_bundle)

    @run_id = 0
  end

  after :all do
    # Cleanup after ourselves
    FileUtils.rm_rf(@test_dir)
  end

  before :each do
    # Create a directory per scenario to store log files, pid files, etc.
    @run_dir = File.join(@test_dir, "run_#{run_id_ctr}")
    create_dir(@run_dir)

    # NATS
    port = VCAP.grab_ephemeral_port
    pid_file = File.join(@run_dir, 'nats.pid')
    @nats_cfg = {
      :port     => port,
      :pid_file => pid_file,
      :cmd      => "ruby -S bundle exec nats-server -p #{port} -P #{pid_file}",
      :uri      => "nats://localhost:#{port}",
      :outdir   => @run_dir,
    }
    @nats_server = NatsComponent.new(@nats_cfg)

    # DEA
    @dea_cfg = {
      'base_dir'     => @run_dir,
      'filer_port'   => VCAP.grab_ephemeral_port,
      'mbus'         => @nats_cfg[:uri],
      'intervals'    => {'heartbeat' => 1},
      'log_level'    => 'DEBUG',
      'multi_tenant' => true,
      'max_memory'   => 4096,
      'secure'       => false,
      'enforce_ulimit' => true,
      'local_route'  => '127.0.0.1',
      'pid'          => File.join(@run_dir, 'dea.pid'),
      'runtimes'     => {
        'ruby18' => {
          'executable'        => '/usr/bin/ruby',
          'version'           => '1.8.7',
          'version_flag'      => "-e 'puts RUBY_VERSION'"
        }
      },
      'disable_dir_cleanup' => true,
    }
    @dea_config_file = File.join(@run_dir, 'dea.config')
    File.open(@dea_config_file, 'w') {|f| YAML.dump(@dea_cfg, f) }
    @dea_agent = DeaComponent.new("ruby -r#{nats_timeout_path} #{dea_path} -c #{@dea_config_file}", @dea_cfg['pid'], @dea_cfg, @run_dir)
    @app_state_file = File.join(@run_dir, 'db', 'applications.json')
  end

  after :each do
    run_id_ctr += 1
  end

  it 'should not snapshot state if the initial connect to NATS fails' do
    File.exists?(@app_state_file).should be_false
    @dea_agent.start
    wait_for { Process.waitpid(@dea_agent.pid, Process::WNOHANG) != nil }.should be_true
    File.exists?(@app_state_file).should be_false
  end

  describe 'when running' do
    before :each do
      @nats_server.start
      wait_for { @nats_server.is_ready? }.should be_true

      # The dea announces itself on startup (after all initialization has been performed).
      # Listen for that message as a signal that it is ready.
      start_msg = nil
      em_run_with_timeout do
        NATS.start(:uri => @nats_server.uri) do
          NATS.subscribe('dea.start') do |msg|
            start_msg = msg
            EM.stop
          end
          # This is a little weird, but it ensures that our subscribe has been processed
          NATS.publish('foo') { @dea_agent.start }
        end
      end

      start_msg.should_not be_nil
    end

    after :each do
      @dea_agent.stop
      @dea_agent.is_running?.should be_false

      @nats_server.stop
      @nats_server.is_running?.should be_false
    end

    it 'should ensure it can find an executable ruby' do
      # Unknown file
      lambda { DEA::Agent.new({'dea_ruby' => "/tmp/fsd94jklaf98"}) }.should raise_error

      # Non executable file
      lambda { DEA::Agent.new({'dea_ruby' => @dea_config_file}) }.should raise_error
    end

    it 'should ensure that a file-server is running' do
      wait_for { port_open?(@dea_cfg['filer_port']) }.should be_true
    end

    it 'should respond to status requests' do
      send_request(@nats_server.uri, 'dea.status', nil).should_not be_nil
    end

    it 'should respond to discover requests' do
      disc_msg = {'droplet' => 1, 'runtime' => 'ruby18', 'limits' => {'mem' => 1}}.to_json
      send_request(@nats_server.uri, 'dea.discover', disc_msg).should_not be_nil
    end

    it 'should start a droplet when requested' do
      droplet_info = start_droplet(@nats_server.uri, @droplet)
      droplet_info.should_not be_nil
      wait_for { port_open?(droplet_info['port']) }.should be_true
      droplet_info["tags"].should == {"framework"=>"sinatra", "runtime"=>"ruby18"}
      droplet_info["uris"].should == ["test_app.vcap.me"]
    end

    it 'should heartbeat a running droplet' do
      droplet_info = start_droplet(@nats_server.uri, @droplet)
      droplet_info.should_not be_nil
      receive_message(@nats_server.uri, 'dea.heartbeat').should_not be_nil
    end

    it 'should respond to find droplet requests' do
      droplet_info = start_droplet(@nats_server.uri, @droplet)
      droplet_info.should_not be_nil
      req = {'droplet' => @droplet['droplet']}.to_json
      send_request(@nats_server.uri, 'dea.find.droplet', req).should_not be_nil
    end

    it 'should stop a running droplet when requested' do
      droplet_info = start_droplet(@nats_server.uri, @droplet)
      droplet_info.should_not be_nil
      stop_droplet(@nats_server.uri, @droplet)
      wait_for { !port_open?(droplet_info['port']) }.should be_true
    end

    it 'should properly exit when NATS fails to reconnect' do
      @nats_server.stop
      @nats_server.is_running?.should be_false
      wait_for { Process.waitpid(@dea_agent.pid, Process::WNOHANG) != nil }.should be_true
    end

    it 'should snapshot state upon reconnect failure' do
      File.exists?(@app_state_file).should be_false
      @nats_server.stop
      @nats_server.is_running?.should be_false
      wait_for { Process.waitpid(@dea_agent.pid, Process::WNOHANG) != nil }.should be_true
      File.exists?(@app_state_file).should be_true
    end
  end

  def create_dir(dir)
    File.directory?(dir).should be_false
    FileUtils.mkdir(dir)
    File.directory?(dir).should be_true
  end

  def send_request(uri, subj, req, timeout=10)
    response = nil
    em_run_with_timeout(timeout) do
      NATS.start(:uri => uri) do
        NATS.request(subj, req) do |msg|
          response = msg
          EM.stop
        end
      end
    end
    response
  end

  def receive_message(uri, subj, timeout=10)
    ret = nil
    em_run_with_timeout do
      NATS.start(:uri => uri) do
        NATS.subscribe('dea.heartbeat') do |msg|
          ret = msg
          EM.stop
        end
      end
    end
    ret
  end

  def start_droplet(uri, droplet, timeout=10)
    disc_msg = {
      'droplet'        => 1,
      'sha1'           => 22,
      'runtime'        => 'ruby18',
      'limits'         => { 'mem' => 1 }
    }.to_json()

    droplet_info = nil
    em_run_with_timeout(timeout) do
      NATS.start(:uri => uri) do
        NATS.request('dea.discover', disc_msg) do |msg|

          # Wait for the app
          NATS.subscribe('router.register') do |msg|
            droplet_info = JSON.parse(msg)
            EM.stop
          end

          # Start the app
          dea_json = JSON.parse(msg)
          NATS.publish('dea.%s.start' % (dea_json['id']), droplet.to_json())
        end
      end
    end

    droplet_info
  end

  # NB: This is intended to be used without the event-loop already running.
  #     (We expect to block here.)
  def em_run_with_timeout(timeout=10)
    EM.run do
      EM.add_timer(timeout) { EM.stop }
      yield
    end
  end

  def stop_droplet(uri, droplet)
    em_run_with_timeout do
      NATS.start(:uri => uri) do
        NATS.publish('dea.stop', { 'droplet' => droplet['droplet'] }.to_json) { EM.stop }
      end
    end
  end

  def create_droplet_bundle(base_dir, bundlename)
    staging_dir = File.join(base_dir, 'staging')
    FileUtils.mkdir(staging_dir)
    File.exists?(staging_dir).should be_true
    {'start_tcpserver.rb' => 'startup',
      'stop_tcpserver.rb' => 'stop',
    }.each do |src, dst|
      src = File.join(File.dirname(__FILE__), src)
      dst = File.join(staging_dir, dst)
      FileUtils.cp(src, dst)
      FileUtils.chmod(0755, dst)
      File.exists?(dst).should be_true
    end
    system("tar czf #{bundlename} -C #{staging_dir} startup -C #{staging_dir} stop")
    File.exists?(bundlename).should be_true
    FileUtils.rm_rf(staging_dir)
    File.exists?(staging_dir).should be_false
  end

  def droplet_for_bundle(bundle_filename)
    {
      'sha1'     => Digest::SHA1.hexdigest(File.read(bundle_filename)),
      'droplet'  => 1,
      'name'     => 'test_app',
      'services' => {},
      'uris'     => ['test_app.vcap.me'],
      'executableFile' => bundle_filename,
      'executableUri'  => 'http://localhost/foo',
      'runtime'        => 'ruby18',
      'framework'      => 'sinatra'
    }
  end
end
