require 'tmpdir'

require 'spec_helper'


describe VCAP::Stager::Util do
  describe '.fetch_zipped_app' do
    before :each do
      @body     = 'hello world'
      @tmpdir   = Dir.mktmpdir
      @app_uri  = 'http://user:pass@www.foobar.com/zazzle.zip'
      @app_file = File.join(@tmpdir, 'app.zip')
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'should pass along credentials when supplied' do
      stub_request(:get, @app_uri).to_return(:body => @body, :status => 200)
      VCAP::Stager::Util.fetch_zipped_app(@app_uri, '/dev/null')
      a_request(:get, @app_uri).should have_been_made
    end

    it 'should save the file to disk on success' do
      stub_request(:get, @app_uri).to_return(:body => @body, :status => 200)
      VCAP::Stager::Util.fetch_zipped_app(@app_uri, @app_file)
      File.read(@app_file).should == @body
    end

    it 'should raise an exception on non-200 status codes' do
      stub_request(:get, @app_uri).to_return(:body => @body, :status => 404)
      expect do
        VCAP::Stager::Util.fetch_zipped_app(@app_uri, @app_file)
      end.to raise_error(VCAP::Stager::AppDownloadError)
    end

    it 'should delete the created file on error' do
      stub_request(:get, @app_uri).to_return(:body => @body, :status => 200)
      file_mock = mock(:file)
      file_mock.should_receive(:write).with(any_args()).and_raise("Foo")
      File.should_receive(:open).with(@app_file, 'w+').and_yield(file_mock)
      expect do
        VCAP::Stager::Util.fetch_zipped_app(@app_uri, @app_file)
      end.to raise_error("Foo")
      File.exist?(@app_file).should be_false
    end
  end

  describe '.upload_droplet' do
    before :each do
      @body     = 'hello world'
      @tmpdir   = Dir.mktmpdir
      @put_uri  = 'http://user:pass@www.foobar.com/droplet.zip'
      @droplet_file = File.join(@tmpdir, 'droplet.zip')
      File.open(@droplet_file, 'w+') {|f| f.write(@body) }
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'should pass along credentials when supplied' do
      stub_request(:put, @put_uri).to_return(:status => 200)
      VCAP::Stager::Util.upload_droplet(@put_uri, @droplet_file)
      a_request(:put, @put_uri).should have_been_made
    end

    it 'pass the file contents as the body' do
      stub_request(:put, @put_uri).to_return(:status => 200)
      VCAP::Stager::Util.upload_droplet(@put_uri, @droplet_file)
      a_request(:put, @put_uri).with(:body => @body).should have_been_made
    end

    it 'should raise an exception on non-200 status codes' do
      stub_request(:put, @put_uri).to_return(:status => 404)
      expect do
        VCAP::Stager::Util.upload_droplet(@put_uri, @droplet_file)
      end.to raise_error(VCAP::Stager::DropletUploadError)
    end

  end

end
