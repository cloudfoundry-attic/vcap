require File.join(File.dirname(__FILE__), "spec_helper")

require "logger"

describe VCAP::Stager::ProcessRunner do
  describe "#run" do
    it "should return the correct exit status, stdout, and stderr" do
      runner = VCAP::Stager::ProcessRunner.new(nil)

      ret = runner.run("sh -c 'echo foo; echo bar >&2; exit 2'")

      ret[:stdout].should == "foo\n"
      ret[:stderr].should == "bar\n"
      ret[:status].exitstatus.should == 2
    end

    it "should allow commands to be timed out" do
      runner = VCAP::Stager::ProcessRunner.new(nil)

      ret = runner.run("sh -c 'echo foo; sleep 5'", :timeout => 0.25)

      ret[:stdout].should == "foo\n"
      ret[:timed_out].should be_true
    end
  end

  describe "#run_logged" do
    it "should log exit status, stdout, and stderr" do
      log_buf = StringIO.new("")
      logger = Logger.new(log_buf)
      logger.level = Logger::DEBUG
      logger.formatter = proc { |sev, dt, pn, msg| msg }
      runner = VCAP::Stager::ProcessRunner.new(logger)

      runner.run_logged("sh -c 'echo foo; echo bar >&2; exit 2'")

      raw_buf = log_buf.string

      raw_buf.should match(/foo/)
      raw_buf.should match(/bar/)
      raw_buf.should match(/status 2/)
    end
  end
end
