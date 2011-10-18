require 'spec_helper'

describe StagingController do
  before :all do
    VCAP::Logging.setup_from_config({'level' => 'debug2'})
    AppConfig[:staging][:auth] = {
      :user     => 'test',
      :password => 'test',
    }
    @auth = ActionController::HttpAuthentication::Basic.encode_credentials('test', 'test')
  end

  describe '#upload_droplet' do

    before :each do
      request.env["HTTP_AUTHORIZATION"] = @auth
    end

    it 'should return 401 for incorrect credentials' do
      request.env["HTTP_AUTHORIZATION"] = nil
      post :upload_droplet, {:id => 1, :staging_task_id => 'foo'}
      response.status.should == 401
    end

    it 'should return 404 for unknown apps' do
      post :upload_droplet, {:id => 1, :staging_task_id => 'foo'}
      response.status.should == 404
    end

    it 'should return 400 for unknown tasks' do
      App.stubs(:find_by_id).with(1).returns('test')
      post :upload_droplet, {:id => 1, :staging_task_id => 'foo'}
      response.status.should == 400
    end

    it 'should rename the uploaded file correctly' do
      tmpfile = Tempfile.new('test')
      app, droplet, task = stub_test_task(tmpfile)
      File.expects(:rename).with(droplet.path, task.upload_path)
      params = {
        :id      => app.id,
        :staging_task_id => task.task_id,
        :upload  => {:droplet => droplet}
      }
      post :upload_droplet, params
      response.status.should == 200
    end

    it 'should clean up the temporary upload' do
      tmpfile = Tempfile.new('test')
      app, droplet, task = stub_test_task(tmpfile)
      File.expects(:rename).with(droplet.path, task.upload_path)
      FileUtils.expects(:rm_f).with(droplet.path)
      params = {
        :id      => app.id,
        :staging_task_id => task.task_id,
        :upload  => {:droplet => droplet}
      }
      post :upload_droplet, params
      response.status.should == 200
    end
  end

  def stub_test_task(file)
    app = App.new
    app.id = 1
    droplet = Rack::Test::UploadedFile.new(file.path)
    App.stubs(:find_by_id).with(app.id).returns(app)
    task = StagingTask.new(app)
    CloudController.stubs(:use_nginx).returns(false)
    StagingTask.stubs(:find_task).with(task.task_id).returns(task)
    [app, droplet, task]
  end
end
