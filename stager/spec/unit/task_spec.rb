require File.join(File.dirname(__FILE__), 'spec_helper')

require 'tmpdir'

describe VCAP::Stager::Task do
  describe '#creating_staging_dirs' do
    it 'should create the basic directory structure needed for staging' do
      task = VCAP::Stager::Task.new(nil, nil, nil, nil, nil)
      dirs = task.send(:create_staging_dirs)
      File.directory?(dirs[:base]).should be_true
      File.directory?(dirs[:unstaged]).should be_true
      File.directory?(dirs[:staged]).should be_true
      FileUtils.rm_rf(dirs[:base]) if dirs[:base]
    end
  end

  describe '#download_app' do
    before :each do
      @tmp_dir = Dir.mktmpdir
      @task = VCAP::Stager::Task.new(1, nil, nil, nil, nil)
    end

    after :each do
      FileUtils.rm_rf(@tmp_dir)
    end

    it 'should raise an instance of VCAP::Stager::AppDownloadError if the download fails' do
      @task.stub(:run_logged).and_return({:success => false})
      expect { @task.send(:download_app, @tmp_dir, @tmp_dir) }.to raise_error(VCAP::Stager::AppDownloadError)
    end

    it 'should raise an instance of VCAP::Stager::AppUnzipError if the unzip fails' do
      @task.stub(:run_logged).and_return({:success => true}, {:success => false})
      expect { @task.send(:download_app, @tmp_dir, @tmp_dir) }.to raise_error(VCAP::Stager::AppUnzipError)
    end

    it 'should leave the temporary working dir as it found it' do
      glob_exp = File.join(@tmp_dir, '*')
      pre_files = Dir.glob(glob_exp)
      @task.stub(:run_logged).and_return({:success => true}, {:success => true})
      @task.send(:download_app, @tmp_dir, @tmp_dir)
      Dir.glob(glob_exp).should == pre_files
    end
  end

  describe '#run_staging_plugin' do
    before :each do
      @tmp_dir = Dir.mktmpdir
      @props = {
        'runtime'     => 'ruby',
        'framework'   => 'sinatra',
        'services'    => [{}],
        'resources'   => {
          'memory'    => 128,
          'disk'      => 1024,
          'fds'       => 64,
        },
      }
      @task = VCAP::Stager::Task.new(1, @props, nil, nil, nil)
    end

    after :each do
      FileUtils.rm_rf(@tmp_dir)
    end

    it 'should raise an instance of VCAP::Stager::StagingTimeoutError on plugin timeout' do
      @task.stub(:run_logged).and_return({:success => false, :timed_out => true})
      expect { @task.send(:run_staging_plugin, @tmp_dir, @tmp_dir, @tmp_dir, nil) }.to raise_error(VCAP::Stager::StagingTimeoutError)
    end

    it 'should raise an instance of VCAP::Stager::StagingPlugin on plugin failure' do
      @task.stub(:run_logged).and_return({:success => false})
      expect { @task.send(:run_staging_plugin, @tmp_dir, @tmp_dir, @tmp_dir, nil) }.to raise_error(VCAP::Stager::StagingPluginError)
    end

    it 'should leave the temporary working dir as it found it' do
      glob_exp = File.join(@tmp_dir, '*')
      pre_files = Dir.glob(glob_exp)
      @task.stub(:run_logged).and_return({:success => true})
      @task.send(:run_staging_plugin, @tmp_dir, @tmp_dir, @tmp_dir, nil)
      Dir.glob(glob_exp).should == pre_files
    end
  end

  describe '#upload_app' do
    before :each do
      @tmp_dir = Dir.mktmpdir
      @task = VCAP::Stager::Task.new(1, nil, nil, nil, nil)
    end

    after :each do
      FileUtils.rm_rf(@tmp_dir)
    end

    it 'should raise an instance of VCAP::Stager::DropletCreationError if the gzip fails' do
      @task.stub(:run_logged).and_return({:success => false})
      expect { @task.send(:upload_droplet, @tmp_dir, @tmp_dir) }.to raise_error(VCAP::Stager::DropletCreationError)
    end

    it 'should raise an instance of VCAP::Stager::DropletUploadError if the upload fails' do
      @task.stub(:run_logged).and_return({:success => true}, {:success => false})
      expect { @task.send(:upload_droplet, @tmp_dir, @tmp_dir) }.to raise_error(VCAP::Stager::DropletUploadError)
    end

    it 'should leave the temporary working dir as it found it' do
      glob_exp = File.join(@tmp_dir, '*')
      pre_files = Dir.glob(glob_exp)
      @task.stub(:run_logged).and_return({:success => true}, {:success => true})
      @task.send(:upload_droplet, @tmp_dir, @tmp_dir)
      Dir.glob(glob_exp).should == pre_files
    end
  end


  describe '#perform' do
  end
end
