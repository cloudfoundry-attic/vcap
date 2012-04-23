require "tmpdir"

module VCAP
  module Stager
  end
end

# The scratch area used by the staging tasks.
class VCAP::Stager::Workspace
  attr_reader :root_dir,     # Root of the workspace
              :unstaged_dir, # Home to the raw app bits
              :staged_dir    # Home to the modified app bits

  def self.create(tmpdir_base = nil)
    ws = new

    ws.create_paths(tmpdir_base)

    ws
  end

  def destroy
    FileUtils.rm_rf(@root_dir)
  end

  def create_paths(tmpdir_base = nil)
    @root_dir = Dir.mktmpdir(nil, tmpdir_base)

    @unstaged_dir = File.join(@root_dir, "unstaged")
    FileUtils.mkdir(@unstaged_dir, :mode => 0700)

    @staged_dir = File.join(@root_dir, "staged")
    FileUtils.mkdir(@staged_dir, :mode => 0700)
  end
end
