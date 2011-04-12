# Copyright (c) 2009-2011 VMware, Inc.
require "spec_helper"

describe 'PidFile Tests' do
  before :all do
    @pid_file = "/tmp/pidfile_test_%d_%d_%d" % [Process.pid(), Time.now().to_i(), rand(1000)]
  end

  after :each do
    FileUtils.rm_f(@pid_file)
  end

  it "should create a pidfile if one doesn't exist" do
    VCAP::PidFile.new(@pid_file)
    File.exists?(@pid_file).should be_true
  end

  it "should overwrite pid file if pid file exists and contained pid isn't running" do
    fork { VCAP::PidFile.new(@pid_file) }
    Process.wait()
    VCAP::PidFile.new(@pid_file)
    pid = File.open(@pid_file) {|f| pid = f.read().strip().to_i()}
    pid.should == Process.pid()
  end

  it "should throw exception if pid file exists and contained pid has running process" do
    child_pid = fork {
      VCAP::PidFile.new(@pid_file)
      Signal.trap('HUP') { exit }
      while true; end
    }
    sleep(1)
    thrown = false
    begin
      VCAP::PidFile.new(@pid_file)
    rescue VCAP::PidFile::ProcessRunningError => e
      thrown = true
    end
    Process.kill('HUP', child_pid)
    Process.wait()
    thrown.should be_true
  end

  it "shouldn't throw an exception if current process's pid is in pid file" do
    p1 = VCAP::PidFile.new(@pid_file)
    p2 = VCAP::PidFile.new(@pid_file)
  end

  it "unlink() should remove pidfile correctly" do
    pf = VCAP::PidFile.new(@pid_file)
    pf.unlink()
    File.exists?(@pid_file).should be_false
  end

  it "unlink_at_exit() should remove pidfile upon exit" do
    child_pid = fork {
      pf = VCAP::PidFile.new(@pid_file)
      pf.unlink_at_exit()
      Signal.trap('HUP') { exit }
      while true; end
    }
    sleep 1
    Process.kill('HUP', child_pid)
    Process.wait()
    File.exists?(@pid_file).should be_false
  end

  it "unlink_on_signals() should remove pidfile upon receipt of signal" do
    child_pid = fork {
      pf = VCAP::PidFile.new(@pid_file)
      pf.unlink_on_signals('HUP')
      Signal.trap('TERM') { exit }
      while true; end
    }
    sleep 1
    Process.kill('HUP', child_pid)
    sleep 1
    Process.kill('TERM', child_pid)
    Process.wait()
    File.exists?(@pid_file).should be_false

  end

end
