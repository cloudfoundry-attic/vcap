# Copyright (c) 2009-2011 VMware, Inc.
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'spec_helper'

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
      agent = DEA::Agent.new(
        'log_file'  => File.join(UNIT_TESTS_DIR, 'test.log'),
        'intervals' => { 'heartbeat' => 1 },
        'base_dir'  => UNIT_TESTS_DIR
      )
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
      agent = DEA::Agent.new(
        'intervals' => { 'heartbeat' => 1 },
        'base_dir'  => UNIT_TESTS_DIR
      )
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
      agent = DEA::Agent.new(
        'intervals' => { 'heartbeat' => 1 },
        'base_dir'  => UNIT_TESTS_DIR
      )
      apps_dir = create_apps_dir(UNIT_TESTS_DIR)
      File.directory?(apps_dir).should be_true

      inst_dir = File.join(apps_dir, 'test_instance_dir')
      FileUtils.mkdir(inst_dir)
      File.directory?(inst_dir).should be_true

      agent.instance_variable_set(:@logger, double(:logger).as_null_object)
      agent.instance_variable_set(:@droplets, {})
      agent.delete_untracked_instance_dirs

      File.directory?(inst_dir).should be_false
    end
  end

  describe '#crashes_reaper' do
    it 'should remove instance dirs for crashed apps' do
      agent = DEA::Agent.new(
        'intervals' => { 'heartbeat' => 1 },
        'base_dir'  => UNIT_TESTS_DIR
      )
      apps_dir = create_apps_dir(UNIT_TESTS_DIR)
      File.directory?(apps_dir).should be_true

      inst_dir = File.join(apps_dir, 'test_instance_dir')
      FileUtils.mkdir(inst_dir)
      File.directory?(inst_dir).should be_true

      droplets = {
        0 => {
          0 => {
            :dir   => inst_dir,
            :state => :CRASHED,
            :state_timestamp => Time.now.to_i - DEA::Agent::CRASHES_REAPER_TIMEOUT - 60,
          },
        }
      }
      agent.instance_variable_set(:@logger, double(:logger).as_null_object)
      agent.instance_variable_set(:@droplets, droplets)

      EM.run do
        agent.crashes_reaper
        EM.stop
      end

      File.directory?(inst_dir).should be_false
    end
  end

  def create_apps_dir(base_dir)
    apps_dir = File.join(base_dir, 'apps')
    FileUtils.mkdir(apps_dir)
    apps_dir
  end
end
