require File.join(File.dirname(__FILE__), "spec_helper")

describe VCAP::Stager::Workspace do
  before :each do
    @ws_root = Dir.mktmpdir
  end

  after :each do
    FileUtils.rm_rf(@ws_root)
  end

  describe ".create" do
    it "should return a materialized workspace" do
      ws = VCAP::Stager::Workspace.create(@ws_root)

      [:root_dir, :unstaged_dir, :staged_dir].each do |name|
        File.directory?(ws.send(name)).should be_true
      end
    end
  end

  describe "#destroy" do
    it "should remove the workspace from the filesystem" do
      ws = VCAP::Stager::Workspace.create(@ws_root)
      ws.destroy

      [:root_dir, :unstaged_dir, :staged_dir].each do |name|
        File.exist?(ws.send(name)).should be_false
      end
    end
  end
end
