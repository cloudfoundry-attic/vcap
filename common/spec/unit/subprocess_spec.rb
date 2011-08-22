require 'spec_helper'

describe VCAP::Subprocess do
  before :each do
    @subprocess = VCAP::Subprocess.new
  end

  describe '#run' do
    it 'should capture both stdout and stderr' do
      stdout, stderr, status = @subprocess.run('echo -n foo >&2')
      stdout.should == ''
      stderr.should == 'foo'
      status.should == 0

      stdout, stderr, status = @subprocess.run('echo -n foo')
      stdout.should == 'foo'
      stderr.should == ''
      status.should == 0
    end

    it 'should raise exceptions on exit status mismatch' do
      begin
        ex_thrown = false
        @subprocess.run('exit 10')
      rescue VCAP::SubprocessStatusError => se
        ex_thrown = true
        se.status.exitstatus == 10
      ensure
        ex_thrown.should be_true
      end
    end

    it 'should properly validate nonzero exit statuses' do
      stdout, stderr, status = @subprocess.run('exit 10', 10)
      status.exitstatus.should == 10
    end

    it 'should kill processes that run too long' do
      expect do
        VCAP::Subprocess.run('sleep 5', 0, 1)
      end.to raise_error(VCAP::SubprocessTimeoutError)
    end

    it 'should call previously installed SIGCHLD handlers' do
      handler_called = false
      trap('CLD') { handler_called = true }
      VCAP::Subprocess.run('echo foo')
      handler_called.should be_true
    end
  end
end
