require 'spec_helper'

require 'fileutils'
require 'logging'
require 'tmpdir'

describe 'VCAP#create_logger' do
  before :all do
    @tmpdir = Dir.mktmpdir
    Dir.exists?(@tmpdir).should be_true
  end

  after :all do
    FileUtils.rm_rf(@tmpdir)
    Dir.exists?(@tmpdir).should be_false
  end

  it 'should create a stdout logger by default' do
    log = VCAP.create_logger('test')
    appenders = log.instance_variable_get '@appenders'
    appenders.length.should == 1
    appenders[0].class.should == Logging::Appenders::Stdout
  end

  it 'should create a file logger if logfile given, but no rotation interval supplied' do
    logfilename = File.join(@tmpdir, 'no_rotate.log')
    log = VCAP.create_logger('test', :log_file => logfilename)
    appenders = log.instance_variable_get '@appenders'
    appenders.length.should == 1
    appenders[0].class.should == Logging::Appenders::File
  end

  it 'should create a rolling file logger if logfile given and rotation interval supplied' do
    logfilename = File.join(@tmpdir, 'no_rotate.log')
    log = VCAP.create_logger('test', :log_file => logfilename, :log_rotation_interval => 'daily')
    appenders = log.instance_variable_get '@appenders'
    appenders.length.should == 1
    appenders[0].class.should == Logging::Appenders::RollingFile
  end

  it 'should correctly rotate files by age' do
    logfilename = File.join(@tmpdir, 'rotate_by_age.log')
    log = VCAP.create_logger('tst', :log_file => logfilename, :log_rotation_interval => 1)
    log.info "TEST LINE 1"
    sleep(2)
    log.info "TEST_LINE 2"
    logs = Dir.glob(File.join(@tmpdir, 'rotate_by_age.*log'))
    logs.count.should == 2
  end
end
