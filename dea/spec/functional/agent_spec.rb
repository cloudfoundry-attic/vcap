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
  PID = Process.pid()
  TEST_DIR = "/tmp/dea_agent_tests_#{PID}_#{Time.now.to_i}"
  NATS_PORT = VCAP.grab_ephemeral_port
  NATS_PID_FILE = File.join(TEST_DIR, 'nats.pid')
  NATS_CMD = "ruby -S bundle exec nats-server -p #{NATS_PORT} -P #{NATS_PID_FILE}"
  NATS_URI = "nats://localhost:#{NATS_PORT}"
  APP_DIR = File.join(TEST_DIR, 'apps')
  DEA_CONFIG_FILE = File.join(TEST_DIR, 'dea.config')
  DEA_CONFIG = {
    'base_dir'     => APP_DIR,
    'filer_port'   => nil,  # Set in before :each
    'mbus'         => NATS_URI,
    'intervals'    => {'heartbeat' => 1},
    'log_level'    => 'DEBUG',
    'multi_tenant' => true,
    'max_memory'   => 4096,
    'secure'       => false,
    'local_route'  => 'localhost',
    'pid'          => File.join(TEST_DIR, 'dea.pid'),
    'runtimes'     => {
      'ruby18' => {
        'executable'        => '/usr/bin/ruby',
        'version'           => '1.8.7',
        'version_flag'      => "-e 'puts RUBY_VERSION'"
      }
    },
    'disable_dir_cleanup' => true,
  }

  nats_timeout = File.expand_path(File.join(File.dirname(__FILE__), 'nats_timeout'))
  dea_agent = File.expand_path(File.join(__FILE__, "../../../bin/dea -c #{DEA_CONFIG_FILE}"))

  DEA_CMD = "ruby -r#{nats_timeout} #{dea_agent}"

  TCPSERVER_DROPLET_BUNDLE = File.join(TEST_DIR, 'droplet')

  before :all do
    FileUtils.mkdir(TEST_DIR)
    File.directory?(TEST_DIR).should be_true
    @nats_server = NatsComponent.new(NATS_CMD, NATS_PID_FILE, NATS_PORT, TEST_DIR)
    @dea_agent = DeaComponent.new(DEA_CMD, DEA_CONFIG['pid'], DEA_CONFIG, TEST_DIR)
    create_droplet_bundle(TCPSERVER_DROPLET_BUNDLE)
    @droplet = droplet_for_bundle(TCPSERVER_DROPLET_BUNDLE)
    at_exit do
      @nats_server.stop
      @dea_agent.stop
    end

    @nats_server.start()
    @nats_server.is_running?().should be_true
  end

  after :all do
    # Cleanup after ourselves
    FileUtils.rm_rf(TEST_DIR)
  end

  before :each do
    # Setup app dir
    File.directory?(APP_DIR).should be_false
    FileUtils.mkdir(APP_DIR)
    File.directory?(APP_DIR).should be_true

    # Pick a different ephemeral port for each run since SO_REUSEADDR isn't set for the filer. If we use a single port and quickly
    # stop the dea and restart it, there is a chance that the addr is in TIME_WAIT when we attempt to start the dea again. This will
    # prevent the filer from binding to the port and ultimately cause our tests to fail.
    DEA_CONFIG['filer_port'] = VCAP.grab_ephemeral_port

    # Write dea config
    File.exists?(DEA_CONFIG_FILE).should be_false
    write_config(DEA_CONFIG_FILE, DEA_CONFIG)
    File.exists?(DEA_CONFIG_FILE).should be_true
  end

  after :each do
    @dea_agent.stop()
    @dea_agent.is_running?().should be_false

    # Cleanup app dir
    FileUtils.rm_rf(APP_DIR)
    File.directory?(APP_DIR).should be_false

    # Cleanup config
    FileUtils.rm_f(DEA_CONFIG_FILE)
    File.exists?(DEA_CONFIG_FILE).should be_false
  end

  # ========== DEA Functionality tests ==========

  it 'should ensure it can find an executable ruby' do
    # Unknown file
    lambda { DEA::Agent.new({'dea_ruby' => "/tmp/fsd94jklaf98"}) }.should raise_error

    # Non executable file
    lambda { DEA::Agent.new({'dea_ruby' => DEA_CONFIG_FILE}) }.should raise_error
  end

  it 'should ensure that a file-server is running' do
    @dea_agent.start()
    @dea_agent.is_running?().should be_true
    wait_for { port_open?(DEA_CONFIG['filer_port']) }
    port_open?(DEA_CONFIG['filer_port']).should be_true
  end

  it 'should announce itself on startup' do
    start_msg = nil
    em_run_with_timeout do
      NATS.start(:uri => NATS_URI) do
        NATS.subscribe('dea.start') do |msg|
          start_msg = msg
          EM.stop
        end
        # This is a little weird, but it ensures that our subscribe has been processed
        NATS.publish('foo') do
          @dea_agent.start()
          @dea_agent.is_running?().should be_true
        end
      end
    end

    start_msg.should_not be_nil
  end

  it 'should respond to status requests' do
    @dea_agent.start()
    @dea_agent.is_running?().should be_true
    status = nil
    em_run_with_timeout do
      NATS.start(:uri => NATS_URI) do
        NATS.request('dea.status') do |msg|
          status = msg
          EM.stop
        end
      end
    end

    status.should_not be_nil
  end

  it 'should respond to discover requests' do
    @dea_agent.start()
    @dea_agent.is_running?().should be_true
    agent = nil
    disc_msg = {'droplet' => 1, 'runtime' => 'ruby18', 'limits' => {'mem' => 1}}.to_json()
    em_run_with_timeout do
      NATS.start(:uri => NATS_URI) do
        NATS.request('dea.discover', disc_msg) do |msg|
          agent = msg
          EM.stop
        end
      end
    end

    agent.should_not be_nil
  end

  it 'should start a droplet when requested' do
    @dea_agent.start()
    @dea_agent.is_running?().should be_true
    droplet_info = start_droplet(@droplet)
    droplet_info.should_not be_nil
    running = wait_for { port_open?(droplet_info['port']) }
    running.should be_true
  end

  it 'should heartbeat a running droplet' do
    @dea_agent.start()
    @dea_agent.is_running?().should be_true
    droplet_info = start_droplet(@droplet)
    droplet_info.should_not be_nil

    hb_recvd = false
    em_run_with_timeout do
      NATS.start(:uri => NATS_URI) do

        # Wait for heartbeat
        NATS.subscribe('dea.heartbeat') do |msg|
          hb_recvd = true
          EM.stop
        end
      end
    end

    hb_recvd.should be_true
  end

  it 'should respond to find droplet requests' do
    @dea_agent.start()
    @dea_agent.is_running?().should be_true
    droplet_info = start_droplet(@droplet)
    droplet_info.should_not be_nil

    found_droplet = false
    em_run_with_timeout do
      NATS.start(:uri => NATS_URI) do
        NATS.request('dea.find.droplet', {'droplet' => @droplet['droplet']}.to_json()) do |msg|
          msg_json = JSON.parse(msg)
          found_droplet = true
          EM.stop
        end
      end
    end

    found_droplet.should be_true
  end

  it 'should stop a running droplet when requested' do
    @dea_agent.start()
    @dea_agent.is_running?().should be_true
    droplet_info = start_droplet(@droplet)
    droplet_info.should_not be_nil
    stop_droplet(@droplet)
    stopped = wait_for { !port_open?(droplet_info['port']) }
    stopped.should be_true
  end

  it 'should properly exit when NATS fails to reconnect' do
    @nats_server.kill_server
    @nats_server.is_running?.should be_false
    sleep(0.5)
    @dea_agent.is_running?.should be_false
  end


  # ========== Helpers ==========

  def start_droplet(droplet, timeout=10)
    disc_msg = {
      'droplet'        => 1,
      'sha1'           => 22,
      'runtime'        => 'ruby18',
      'limits'         => { 'mem' => 1 }
    }.to_json()

    droplet_info = nil
    em_run_with_timeout do
      NATS.start(:uri => NATS_URI) do
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

  def em_run_with_timeout(timeout=10)
    EM.run do
      EM.add_timer(timeout) { EM.stop }
      yield
    end
  end

  def stop_droplet(droplet)
    em_run_with_timeout do
      NATS.start(:uri => NATS_URI) do
        NATS.publish('dea.stop', { 'droplet' => droplet['droplet'] }.to_json) { EM.stop }
      end
    end
  end

  def write_config(config_file, config)
    File.open(config_file, 'w') do |f|
      YAML.dump(config, f)
    end
  end

  def create_droplet_bundle(bundlename)
    staging_dir = File.join(TEST_DIR, 'staging')
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
      'runtime'        => 'ruby18'
    }
  end
end
