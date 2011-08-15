require 'tmpdir'

module StagingSpecHelpers
  AUTOSTAGING_JAR = 'auto-reconfiguration-0.6.0-BUILD-SNAPSHOT.jar'

  # Importantly, this returns a Pathname instance not a String.
  # This allows you to write: app_fixture_base_directory.join('subdir', 'subsubdir')
  def app_fixture_base_directory
    Rails.root.join('spec', 'fixtures', 'apps')
  end

  # Set the app fixture that the current spec will use.
  # TODO - Ensure that this is is cleared between groups.
  def app_fixture(name)
    @app_fixture = name.to_s
  end

  def app_source(tempdir = nil)
    unless @app_fixture
      raise "Call 'app_fixture :name_of_app' before using app_source"
    end
    app_dir = app_fixture_base_directory.join(@app_fixture)
    if File.exist?(warfile = app_dir.join('source.war'))
      # packaged WAR file
      tempdir ||= Dir.mktmpdir(@app_fixture)
      output = `unzip -q #{warfile} -d #{tempdir} 2>&1`
      unless $? == 0
        raise "Failed to unpack #{@app_fixture} WAR file: #{output}"
      end
      tempdir.to_s
    else
      # exploded directory
      app_dir.join('source').to_s
    end
  end

  # If called without a block, returns the staging output directory as a string.
  # You must manually clean up the directory thus created.
  # If called with a block, yields the staged directory as a Pathname, and
  # automatically deletes it when the block returns.
  def stage(framework, env = {})
    raise "Call 'app_fixture :name_of_app' before staging" unless @app_fixture
    environment_json = Yajl::Encoder.encode(env)
    plugin_klass = StagingPlugin.load_plugin_for(framework)
    working_dir = Dir.mktmpdir("#{@app_fixture}-staged")
    source_tempdir = nil
    # TODO - There really needs to be a single helper to track tempdirs.
    source_dir = case framework
                 when /spring|grails|lift|java_web/
                   source_tempdir = Dir.mktmpdir(@app_fixture)
                   app_source(source_tempdir)
                 else
                   app_source
                 end
    stager = plugin_klass.new(source_dir, working_dir, environment_json)
    stager.stage_application
    return working_dir unless block_given?
    Dir.chdir(working_dir) do
      yield Pathname.new(working_dir), Pathname.new(app_source)
    end
    nil
  ensure
    if block_given?
      FileUtils.rm_r(working_dir)
    end
    FileUtils.rm_r(source_tempdir) if source_tempdir
  end
end

