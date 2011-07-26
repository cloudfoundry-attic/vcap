require File.join(File.dirname(__FILE__), 'spec_helper')

describe VCAP::Stager::Task do
  describe '#perform' do
    before :each do
      @tmp_dir = Dir.mktmpdir
      @zipped_app_path = File.join(@tmp_dir, 'app.zip')
      @unstaged_dir    = File.join(@tmp_dir, 'unstaged')
      @staged_dir      = File.join(@tmp_dir, 'staged')
      @droplet_path    = File.join(@tmp_dir, 'droplet.tgz')
      VCAP::Stager.config = {:dirs => {:manifests => @tmp_dir}}
   end

    after :each do
      FileUtils.rm_rf(@tmp_dir)
    end

    it 'should result in failure if fetching the app bits fails' do
      task = make_task
      VCAP::Stager::Util.should_receive(:fetch_zipped_app).with(any_args()).and_raise("Download failed")
      expect { task.perform }.to raise_error "Download failed"
      task.result.was_success?.should be_false
    end

    it 'should result in failure if unzipping the app bits fails' do
      task = make_task
      VCAP::Stager::Util.should_receive(:fetch_zipped_app).with(any_args()).and_return(nil)
      # We could mock out the call, but this is more fun
      File.open(File.join(@tmp_dir, 'app.zip'), 'w+') {|f| f.write("GARBAGE") }
      expect { task.perform }.to raise_error(VCAP::SubprocessStatusError)
      task.result.was_success?.should be_false
    end

    it 'should result in failure if staging the app fails' do
      task = make_task
      nullify_method(VCAP::Stager::Util, :fetch_zipped_app)
      nullify_method(VCAP::Subprocess, :run, "unzip -q #{@zipped_app_path} -d #{@unstaged_dir}")
      task.should_receive(:run_staging_plugin).and_raise("Staging failed")
      expect { task.perform }.to raise_error("Staging failed")
      task.result.was_success?.should be_false
    end

    it 'should result in failure if creating the droplet fails' do
      task = make_task
      nullify_method(VCAP::Stager::Util, :fetch_zipped_app)
      nullify_method(VCAP::Subprocess, :run, "unzip -q #{@zipped_app_path} -d #{@unstaged_dir}")
      nullify_method(task, :run_staging_plugin)
      VCAP::Subprocess.should_receive(:run).with("cd #{@staged_dir}; COPYFILE_DISABLE=true tar -czf #{@droplet_path} *").and_raise("Creating droplet failed")
      expect { task.perform }.to raise_error("Creating droplet failed")
      task.result.was_success?.should be_false
    end

    it 'should result in failure if uploading the droplet fails' do
      task = make_task
      nullify_method(VCAP::Stager::Util, :fetch_zipped_app)
      nullify_method(VCAP::Subprocess, :run, "unzip -q #{@zipped_app_path} -d #{@unstaged_dir}")
      nullify_method(task, :run_staging_plugin)
      nullify_method(VCAP::Subprocess, :run, "cd #{@staged_dir}; COPYFILE_DISABLE=true tar -czf #{@droplet_path} *")
      VCAP::Stager::Util.should_receive(:upload_droplet).with(any_args()).and_raise("Upload failed")
      expect { task.perform }.to raise_error("Upload failed")
      task.result.was_success?.should be_false
    end

    it 'should result in failure if publishing the result fails' do
      task = make_task([])
      task.should_receive(:save_result).twice().and_return(nil)
      nullify_method(VCAP::Stager::Util, :fetch_zipped_app)
      nullify_method(VCAP::Subprocess, :run, "unzip -q #{@zipped_app_path} -d #{@unstaged_dir}")
      nullify_method(task, :run_staging_plugin)
      nullify_method(VCAP::Subprocess, :run, "cd #{@staged_dir}; COPYFILE_DISABLE=true tar -czf #{@droplet_path} *")
      nullify_method(VCAP::Stager::Util, :upload_droplet)
      task.should_receive(:publish_result).and_raise(VCAP::Stager::ResultPublishingError)
      expect { task.perform }.to raise_error(VCAP::Stager::ResultPublishingError)
      task.result.was_success?.should be_false
    end

    it 'should clean up its temporary directory' do
      task = make_task
      VCAP::Stager::Util.should_receive(:fetch_zipped_app).with(any_args()).and_raise("Download failed")
      FileUtils.should_receive(:rm_rf).with(@tmp_dir).twice
      expect { task.perform }.to raise_error
    end

  end

  def nullify_method(instance, method, *args)
    if args.length > 0
      instance.should_receive(method).with(*args).and_return(nil)
    else
      instance.should_receive(method).with(any_args()).and_return(nil)
    end
  end

  def make_task(null_methods=[:save_result, :publish_result])
    task = VCAP::Stager::Task.new('test', nil, nil, nil, nil)
    dirs = {
      :base     => @tmp_dir,
      :unstaged => @unstaged_dir,
      :staged   => @staged_dir,
    }
    task.should_receive(:create_staging_dirs).and_return(dirs)
    for meth in null_methods
      task.should_receive(meth).and_return(nil)
    end
    task
  end
end
