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
      Open3.stub!(:capture3).and_return(['foo', 'bar', 127])
      begin
        ex_thrown = false
        @subprocess.run('zazzle')
      rescue VCAP::SubprocessError => se
        ex_thrown = true
        se.command.should == 'zazzle'
        se.stdout.should  == 'foo'
        se.stderr.should  == 'bar'
        se.exit_status.should == 127
      ensure
        ex_thrown.should be_true
      end
    end
  end
end
