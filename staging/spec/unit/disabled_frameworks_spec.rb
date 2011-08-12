require 'spec_helper'

describe "A Framework should be able to be disabled" do

  it 'should not list a disabled framework' do
    node_path = File.join(STAGING_TEMP, 'node.yml')
    node_manifest = File.read(node_path)
    node_manifest += "disabled: true"
    File.open(node_path, 'w') {|f| f.write(node_manifest) }
    StagingPlugin.load_all_manifests
    manifests = StagingPlugin.manifests
    manifests.should_not have_key 'node'
  end

end
