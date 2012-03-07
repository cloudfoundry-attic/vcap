# Copyright (c) 2009-2011 VMware, Inc.
require File.join(File.dirname(__FILE__), 'spec_helper')

require 'dea/agent'

describe 'DEA Agent' do
  UNIT_TESTS_DIR = "/tmp/dea_agent_unit_tests_#{Process.pid}_#{Time.now.to_i}"

  before :each do
    FileUtils.mkdir(UNIT_TESTS_DIR)
    File.directory?(UNIT_TESTS_DIR).should be_true
  end

  after :each do
    FileUtils.rm_rf(UNIT_TESTS_DIR)
    File.directory?(UNIT_TESTS_DIR).should be_false
  end

  describe '.ensure_writable' do
    it "should raise exceptions if directory isn't writable" do
      dir = File.join(UNIT_TESTS_DIR, 'not_writable')
      FileUtils.mkdir(dir)
      File.directory?(dir).should be_true
      FileUtils.chmod(0500, dir)
      lambda { DEA::Agent.ensure_writable(dir) }.should raise_error
    end
  end

  describe '#dump_apps_dir' do
    it "should log directory summary and details" do
      agent = make_test_agent
      apps_dir = create_apps_dir(UNIT_TESTS_DIR)
      File.directory?(apps_dir).should be_true

      du_pid = agent.dump_apps_dir
      begin
        Process.waitpid(du_pid)
      rescue Errno::ECHILD
        # The agent detaches du_pid, consequently, the ruby thread that was set up
        # to reap the child status may have already done so.
      end

      logs = Dir.glob(File.join(UNIT_TESTS_DIR, 'apps.du.*'))
      logs.length.should == 2
    end
  end

  describe '#delete_untracked_instance_dirs' do
    it 'should not remove instance dirs for tracked apps' do
      agent = make_test_agent
      apps_dir = create_apps_dir(UNIT_TESTS_DIR)
      File.directory?(apps_dir).should be_true

      inst_dir = File.join(apps_dir, 'test_instance_dir')
      FileUtils.mkdir(inst_dir)
      File.directory?(inst_dir).should be_true

      agent.instance_variable_set(:@droplets, {1 => {0 => {:dir => inst_dir}}})
      agent.delete_untracked_instance_dirs

      File.directory?(inst_dir).should be_true
    end

    it 'should remove instance dirs for untracked apps' do
      agent = make_test_agent
      apps_dir = create_apps_dir(UNIT_TESTS_DIR)
      File.directory?(apps_dir).should be_true

      inst_dir = File.join(apps_dir, 'test_instance_dir')
      FileUtils.mkdir(inst_dir)
      File.directory?(inst_dir).should be_true

      agent.instance_variable_set(:@droplets, {})
      agent.delete_untracked_instance_dirs

      File.directory?(inst_dir).should be_false
    end
  end

  describe '#crashes_reaper' do
    it 'should remove instance dirs for crashed apps' do
      agent = make_test_agent
      inst_dir = create_crashed_app(UNIT_TESTS_DIR)
      set_crashed_app_state(agent, inst_dir)

      EM.run do
        agent.crashes_reaper
        EM.stop
      end

      File.directory?(inst_dir).should be_false
    end
  end

  describe '#stage_app_dir' do
    before :each do
      @tmp_dir = Dir.mktmpdir
      @bad_tgz = File.join(@tmp_dir, 'test.tgz')
      File.open(@bad_tgz, 'w+') {|f| f.write("Hello!") }
    end

    after :each do
      FileUtils.rm_rf(@tmp_dir)
    end

    it 'should return false if creating the instance dir fails' do
      agent = make_test_agent
      # Foo doesn't exist, so creating foo/bar should fail
      inst_dir = File.join(@tmp_dir, 'foo', 'bar')
      agent.stage_app_dir(nil, nil, nil, @bad_tgz, inst_dir, nil).should be_false
    end

    it 'should return false if creating the instance dir fails' do
      agent = make_test_agent
      inst_dir = File.join(@tmp_dir, 'foo')
      # @bad_tgz isn't a valid tar file, so extraction should fail
      agent.stage_app_dir(nil, nil, nil, @bad_tgz, inst_dir, nil).should be_false
    end
  end

  describe '#cleanup_droplet' do
    it 'should rechown instance dirs for crashed apps' do
      agent = make_test_agent
      inst_dir = create_crashed_app(UNIT_TESTS_DIR)
      set_crashed_app_state(agent, inst_dir)

      # Use Rspec "EM.system.should_recieve ... "cmd here"
      #EM.should_receive(:system).once.with("chown -R #{Process.euid}:#{Process.egid} #{inst_dir}")
      EM.should_receive(:system).once
      agent.cleanup_droplet(agent.instance_variable_get(:@droplets)[0][0])

      # Is this test blocking? Does it matter?
      File.owned?(inst_dir).should be_true
    end
  end

  describe '#parse_df_percent_used' do
    it 'should return the disk usage percentage as an integer' do
      agent = make_test_agent
      df_output = []
      # Normal case
      df_output << <<-EOT
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/sda1            147550696  83840896  56214632  60% /
EOT

      # FS causes wrapping (seen on QA system)
      df_output << <<-EOT
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/mapper/rootvg-rootvol
                      63051516  36117788  23735124  60% /
EOT
      df_output.each do |out|
        agent.parse_df_percent_used(out).should == 60
      end
    end

    it 'should return nil on unexpected/malformed input' do
      agent = make_test_agent
      invalid_output = []
      # Internal usage only calls with a single path, so we only
      # expect two lines
      invalid_output << <<-EOT
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/sda1            147550696  83840896  56214632  60% /
/dev/sda1            147550696  83840896  56214632  60% /
EOT

      # Extra fields
      invalid_output << <<-EOT
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/sda1            147550696  83840896  56214632  60% / f f
EOT

      # Missing fields
      invalid_output << <<-EOT
Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/sda1            147550696  83840896
EOT
      invalid_output.each do |out|
        agent.parse_df_percent_used(out).should == nil
      end
    end
  end

  def create_crashed_app(base_dir)
    apps_dir = create_apps_dir(base_dir)
    File.directory?(apps_dir).should be_true

    inst_dir = File.join(apps_dir, 'test_instance_dir')
    FileUtils.mkdir(inst_dir)
    File.directory?(inst_dir).should be_true

    inst_dir
  end

  def set_crashed_app_state(agent, inst_dir)
    droplets = {
      0 => {
        0 => {
          :dir   => inst_dir,
          :state => :CRASHED,
          :state_timestamp => Time.now.to_i - DEA::Agent::CRASHES_REAPER_TIMEOUT - 60,
        },
      }
    }
    agent.instance_variable_set(:@droplets, droplets)
  end

  def create_apps_dir(base_dir)
    apps_dir = File.join(base_dir, 'apps')
    FileUtils.mkdir(apps_dir)
    apps_dir
  end

  def make_test_agent(overrides={})
    config = {
      'logging'   => {'file' => File.join(UNIT_TESTS_DIR, 'test.log') },
      'intervals' => { 'heartbeat' => 1 },
      'base_dir'  => UNIT_TESTS_DIR,
    }
    config.update(overrides)
    DEA::Agent.new(config)
  end
end
