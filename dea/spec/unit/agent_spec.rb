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
      apps_dir = File.join(UNIT_TESTS_DIR, 'apps')
      FileUtils.mkdir(apps_dir)
      File.directory?(apps_dir).should be_true

      du_pid = agent.dump_apps_dir
      Process.waitpid(du_pid)

      logs = Dir.glob(File.join(UNIT_TESTS_DIR, 'apps.du.*'))
      logs.length.should == 2
    end
  end
end
