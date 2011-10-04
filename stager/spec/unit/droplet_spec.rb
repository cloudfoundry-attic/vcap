require File.join(File.dirname(__FILE__), 'spec_helper')

require 'fileutils'
require 'tmpdir'

describe VCAP::Stager::Droplet do
  describe '#create_skeleton' do
    before :each do
      @src_dir = Dir.mktmpdir
      @dst_dir = Dir.mktmpdir
    end

    after :each do
      FileUtils.rm_rf(@src_dir)
      FileUtils.rm_rf(@dst_dir)
    end

    it 'should create directories expected by other vcap components' do
      droplet = VCAP::Stager::Droplet.new(@dst_dir)
      droplet.create_skeleton(@src_dir)
      # Check that dirs exist to house the feature start/stop scripts
      File.exist?(File.join(@dst_dir, 'vcap', 'script', 'feature_start')).should be_true
      File.exist?(File.join(@dst_dir, 'vcap', 'script', 'feature_stop')).should be_true

      File.exist?(File.join(@dst_dir, 'app')).should be_true
      File.exist?(File.join(@dst_dir, 'logs')).should be_true
    end

    it 'should copy over the vcap start/stop scripts' do
      droplet = VCAP::Stager::Droplet.new(@dst_dir)
      droplet.create_skeleton(@src_dir)
      File.exist?(File.join(@dst_dir, 'startup')).should be_true
      File.exist?(File.join(@dst_dir, 'stop')).should be_true
    end

    it 'should copy over the application source' do
      rel_path = File.join('foo', 'bar', 'baz')
      FileUtils.mkdir_p(File.join(@src_dir, 'foo', 'bar'))
      File.open(File.join(@src_dir, rel_path), 'w+') {|f| f.write("Hello!") }
      droplet = VCAP::Stager::Droplet.new(@dst_dir)
      droplet.create_skeleton(@src_dir)
      File.exist?(File.join(@dst_dir, 'app', rel_path)).should be_true
    end
  end
end
