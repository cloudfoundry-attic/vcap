require 'rspec/core'
require 'rspec/expectations'
require 'webmock/rspec'

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))
require 'vcap/common'
require 'vcap/subprocess'
require 'vcap/stager'

# XXX - Move gem cache out of home dir...

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.expand_path('../support/**/*.rb', __FILE__)].each {|f| require f}

# Created as needed, removed at the end of the spec run.
# Allows us to override staging paths.
STAGING_TEMP = Dir.mktmpdir
StagingPlugin.manifest_root = STAGING_TEMP

RSpec.configure do |config|
  config.before(:all) do
    begin
      VCAP::Subprocess.run("cp -a #{File.join(StagingPlugin::DEFAULT_MANIFEST_ROOT, '*.yml')} #{STAGING_TEMP}")
    rescue VCAP::SubprocessStatusError => e
      puts "Unable to copy staging manifests. Permissions problem?"
      puts "#{e}"
      puts "STDOUT:"
      puts e.stdout
      puts "STDERR"
      puts e.stderr
    rescue => e
      puts "Unable to copy staging manifests. Permissions problem?"
      puts "#{e}"
    end
    File.open(File.join(STAGING_TEMP, 'platform.yml'), 'wb') do |f|
      # XXX - This is better than putting the gem cache in one's home
      # dir, but still not ideal. Having the gem cache around greatly
      # speeds up tests (mostly due to rails).
      cache_dir = File.join('/tmp', '.vcap_gems')
      f.print YAML.dump('cache' => cache_dir)
    end
  end
end

at_exit { FileUtils.rm_r(STAGING_TEMP) }

include WebMock::API
WebMock.allow_net_connect!
