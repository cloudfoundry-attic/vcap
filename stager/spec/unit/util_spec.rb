require File.join(File.dirname(__FILE__), 'spec_helper')

require 'tmpdir'

describe VCAP::Stager::Util::IOBuffer do
  before :each do
    @strs  = ['abc', 'def', 'ghi']
    @ios   = @strs.map {|s| StringIO.new(s) }
    @iobuf = VCAP::Stager::Util::IOBuffer.new(*@ios)
  end

  describe '#size' do
    it 'should be the sum of all the ios\' sizes' do
      @iobuf.size.should == @strs.join().length
    end
  end

  describe '#read' do
    it 'should correctly read all valid (offset, length) pairs' do
      buf = @strs.join
      blen = buf.length
      for ii in 0..blen
        for jj in ii..blen
          @iobuf.rewind()
          @iobuf.read(ii)
          expected = buf[ii, jj] == "" ? nil : buf[ii, jj]
          @iobuf.read(jj).should == expected
        end
      end
    end

    it 'should return nil if all data has been read' do
      @iobuf.read(@iobuf.size + 1)
      @iobuf.read(1).should == nil
    end
  end
end

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
      end.to raise_error
    end

    it 'should delete the created file on error' do
      stub_request(:get, @app_uri).to_return(:body => @body, :status => 200)
      file_mock = mock(:file)
      file_mock.should_receive(:write).with(any_args()).and_raise("Foo")
      File.should_receive(:open).with(@app_file, 'wb+').and_yield(file_mock)
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
      @post_uri  = 'http://user:pass@www.foobar.com/droplet.zip'
      @droplet_file = File.join(@tmpdir, 'droplet.zip')
      File.open(@droplet_file, 'w+') {|f| f.write(@body) }
    end

    after :each do
      FileUtils.rm_rf(@tmpdir)
    end

    it 'should pass along credentials when supplied' do
      stub_request(:post, @post_uri).to_return(:status => 200)
      VCAP::Stager::Util.upload_droplet(@post_uri, @droplet_file)
      a_request(:post, @post_uri).should have_been_made
    end

    it 'should raise an exception on non-200 status codes' do
      stub_request(:post, @post_uri).to_return(:status => 404)
      expect do
        VCAP::Stager::Util.upload_droplet(@post_uri, @droplet_file)
      end.to raise_error
    end
  end

  describe '.run_command' do
    it 'should correctly capture exit status' do
      status = nil
      EM.run do
        VCAP::Stager::Util.run_command('exit 10') do |res|
          status = res[:status]
          EM.stop
        end
      end
      status.exitstatus.should == 10
    end

    it 'should correctly capture stdout' do
      stdout = nil
      EM.run do
        VCAP::Stager::Util.run_command('echo hello world') do |res|
          stdout = res[:stdout]
          EM.stop
        end
      end
      stdout.should == "hello world\n"
    end

    it 'should correctly capture stderr' do
      stderr = nil
      EM.run do
        VCAP::Stager::Util.run_command('ruby -e \'$stderr.puts "hello world"\'') do |res|
          stderr = res[:stderr]
          EM.stop
        end
      end
      stderr.should == "hello world\n"
    end

    it 'should correctly time out commands' do
      timed_out = nil
      EM.run do
        VCAP::Stager::Util.run_command('echo hello world', 0, 5) do |res|
          timed_out = res[:timed_out]
          EM.stop
        end
      end
      timed_out.should == false

      EM.run do
        VCAP::Stager::Util.run_command('sleep 5', 0, 1) do |res|
          timed_out = res[:timed_out]
          EM.stop
        end
      end
      timed_out.should == true
    end
  end

end
