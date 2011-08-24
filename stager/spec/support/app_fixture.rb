require 'vcap/subprocess'

module VCAP
  module Stager
    module Spec
    end
  end
end

def fixture_path(*args)
  base = File.expand_path('../../fixtures', __FILE__)
  File.join(base, *args)
end

class VCAP::Stager::Spec::AppFixture
  attr_reader :name, :source_dir, :staged_dir

  def initialize(name)
    name = name.to_s
    @name       = name
    @source_dir = fixture_path('apps', name, 'source')
    @staged_dir = fixture_path('apps', name, 'staged')
  end

  # If called without a block, returns the staging output directory as a string.
  # You must manually clean up the directory thus created.
  # If called with a block, yields the staged directory as a Pathname, and
  # automatically deletes it when the block returns.
  def stage(framework, env = {})
    plugin_klass = StagingPlugin.load_plugin_for(framework)
    working_dir = Dir.mktmpdir("#{@name}-staged")
    stager = plugin_klass.new(source_dir, working_dir, env)
    stager.stage_application
    if block_given?
      begin
        Dir.chdir(working_dir) do
          yield Pathname.new(working_dir)
        end
      ensure
        FileUtils.rm_r(working_dir)
      end
    else
      working_dir
    end
  end
end

class VCAP::Stager::Spec::JavaAppFixture < VCAP::Stager::Spec::AppFixture
  def initialize(name)
    name = name.to_s
    super(name)

    @source_dir = unpack_warfile(fixture_path('apps', name, 'source.war'))
  end

  private

  def unpack_warfile(warfile_path, tempdir=nil)
    tempdir ||= Dir.mktmpdir
    VCAP::Subprocess.run("unzip -q #{warfile_path} -d #{tempdir}")
    tempdir.to_s
  end
end
