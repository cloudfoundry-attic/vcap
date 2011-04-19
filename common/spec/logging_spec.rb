require 'spec_helper'

require 'fileutils'
require 'logging'
require 'tmpdir'

describe 'VCAP#make_rolling_file_logger' do
  before :all do
    @tmpdir = Dir.mktmpdir
    Dir.exists?(@tmpdir).should be_true
  end

  after :all do
    FileUtils.rm_rf(@tmpdir)
    Dir.exists?(@tmpdir).should be_false
  end

  it 'should correctly rotate files by age' do
    logfilename = File.join(@tmpdir, 'rotate_by_age.log')
    log = Logging.logger(logfilename, :age => 1)
    log.info "TEST LINE 1"
    sleep(2)
    log.info "TEST_LINE 2"
    logs = Dir.glob(File.join(@tmpdir, 'rotate_by_age.*log'))
    logs.count.should == 2
  end
end
