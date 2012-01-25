$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require 'fileutils'
require 'tmpdir'

require 'vcap/plugins/staging/bundle_installer'

class FakeGem
  attr_reader :name
  attr_reader :base_dir
  attr_reader :gem_root

  def initialize(name)
    @name     = name
    @base_dir = Dir.mktmpdir
    @gem_root = File.join(base_dir, name)
    FileUtils.mkdir(@gem_root)
    @sentinel_value = "fake_gem_#{Time.now}"
    sentinel_path = File.join(@gem_root, 'sentinel')
    File.open(sentinel_path, 'w+') do |f|
      f.write(@sentinel_value)
    end
  end

  def installed_at?(app_root, runtime)
    installed_gem_root =
      VCAP::Plugins::Staging::BundleInstaller.installed_gem_path(app_root,
                                                                 runtime,
                                                                 self.name)
    sentinel_path = File.join(installed_gem_root, 'sentinel')
    File.exists?(sentinel_path) && (File.read(sentinel_path) == @sentinel_value)
  end
end

describe VCAP::Plugins::Staging::BundleInstaller do
  ASSETS_DIR    = File.expand_path('../../assets', __FILE__)
  GEMFILE_PATH  = File.join(ASSETS_DIR, 'Gemfile')
  LOCKFILE_PATH = File.join(ASSETS_DIR, 'Gemfile.lock')

  before :all do
    @plugin = VCAP::Plugins::Staging::BundleInstaller.new
  end

  describe '#parse_lockfile' do
    it 'should return the dependencies as an array of [name, version] pairs' do
      deps = @plugin.parse_lockfile(LOCKFILE_PATH)
      deps_expected = [
        'daemons-1.1.6',
        'eventmachine-0.12.10',
        'json_pure-1.6.5',
        'nats-0.4.22.beta.8',
        'rack-1.4.1',
        'thin-1.3.1',
      ]
      deps.should == deps_expected
    end
  end

  describe '#install_gem' do
    before :each do
      @fake_gem = FakeGem.new('test-1.0')
      @app_root = Dir.mktmpdir
    end

    it 'if possible, should install from cache when not vendored' do
      client = mock()
      runtime = 'ruby18'

      client.should_receive(:get_package_path)
            .with("#{@fake_gem.name}.gem", :remote, runtime)
            .and_return(@fake_gem.base_dir)
      @plugin.install_gem(@app_root, @fake_gem.name, runtime, client)
      @fake_gem.installed_at?(@app_root, runtime).should be_true
    end

    it 'if possible, should install from cache when vendored' do
      client = mock()
      runtime = 'ruby18'

      vendor_cache_path = File.join(@app_root, 'vendor', 'cache')
      FileUtils.mkdir_p(vendor_cache_path)
      vendored_gem_path = File.join(vendor_cache_path, "#{@fake_gem.name}.gem")
      FileUtils.touch(vendored_gem_path)

      client.should_receive(:get_package_path)
            .with(vendored_gem_path, :local, runtime)
            .and_return(@fake_gem.base_dir)
      @plugin.install_gem(@app_root, @fake_gem.name, runtime, client)
      @fake_gem.installed_at?(@app_root, runtime).should be_true
    end
  end
end
