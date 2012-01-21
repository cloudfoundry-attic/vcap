require 'spec_helper'

describe "A Framework should be able to have multiple runtimes" do

  before do
    sinatra_path = File.join(STAGING_TEMP, 'sinatra.yml')
    sinatra_manifest = File.read(sinatra_path)
    File.open(sinatra_path, 'w') {|f| f.write(sinatra_manifest) }
    StagingPlugin.load_all_manifests
    @manifests = StagingPlugin.manifests
  end

  it 'should list multiple rutimes' do
    runtime_names = []
    @manifests['sinatra']['runtimes'].each do |r|
      r.each_pair do |rt_name, rt_info|
        runtime_names << rt_name
      end
    end
    runtime_names.should include 'ruby18', 'ruby19'
  end

  it 'should list a default runtime' do
    defaults = []
    @manifests['sinatra']['runtimes'].each do |r|
      r.each_pair do |rt_name, rt_info|
        defaults << rt_info['default']
      end
    end
    defaults.select{ |d| d == true }.size.should eq 1
  end

end
