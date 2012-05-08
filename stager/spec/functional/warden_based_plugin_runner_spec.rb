require "spec_helper"

describe VCAP::Stager::PluginRunner::WardenBased, :needs_warden => true do

  describe "#stage" do
    before :each do
      @src_dir = Dir.mktmpdir
      @dst_dir = Dir.mktmpdir
      @plugin_config = { :socket_path => ENV["WARDEN_SOCKET_PATH"] }
    end

    after :each do
      FileUtils.rm_rf(@src_dir)
      FileUtils.rm_rf(@dst_dir)
    end

    it "should return an error for unknown frameworks" do
      pr = make_plugin_runner(@plugin_config)

      res = pr.stage({ "framework" => "unknown" }, @src_dir, @dst_dir)

      res[:error].should match(/No plugin found/)
    end

    it "should pass the src dir, dst dir, and properties path to the plugin" do
      stage =<<-EOT
      #!/bin/bash
      echo -n $#
      EOT

      pr = make_plugin_runner(@plugin_config,
                              :plugins => { :test => make_plugin(stage) })

      res = pr.stage({ "framework" => "test"}, @src_dir, @dst_dir)

      verify_success(res)

      res[:log].should_not be_nil
      res[:log].should == "3"
    end

    it "should source the environment script if supplied" do
      env = { "NONCE_#{Time.now.to_i}" => Time.now.to_i }
      env_script = write_environment_script(env)

      stage =<<-EOT
      #!/bin/bash
      export
      EOT

      pr = make_plugin_runner(@plugin_config,
                              :environment_path => env_script.path,
                              :plugins => { :test => make_plugin(stage) })

      res = pr.stage({ "framework" => "test"}, @src_dir, @dst_dir)

      verify_success(res)

      res[:log].should_not be_nil
      env.each { |k, v| res[:log].should match(/#{k}="#{v}"/) }
    end

    it "should provide a script to resolve runtimes" do
      stage =<<-EOT
      #!/bin/bash
      runtime_path test
      EOT

      test_runtime_path = Dir.mktmpdir

      pr = make_plugin_runner(@plugin_config,
                              :plugins => { :test => make_plugin(stage) },
                              :runtimes => { "test" => test_runtime_path })

      res = pr.stage({ "framework" => "test"}, @src_dir, @dst_dir)

      verify_success(res)

      res[:log].chomp.should == test_runtime_path
    end

    it "should report stderr when the plugin exits with a nonzero status" do
      stage =<<-EOT
      #!/bin/bash
      echo -n test >&2
      exit 1
      EOT

      pr = make_plugin_runner(@plugin_config,
                              :plugins => { :test => make_plugin(stage) })

      res = pr.stage({ "framework" => "test"}, @src_dir, @dst_dir)

      res[:error].should == "test"
    end

    it "should copy the results from the plugin into the destination dir" do
      stage =<<-EOT
      #!/bin/bash
      cp -r ${1}/* ${2}
      EOT

      test_basename = "test"
      test_contents = "testing123"

      File.open(File.join(@src_dir, test_basename), "w+") do |f|
        f.write(test_contents)
      end

      pr = make_plugin_runner(@plugin_config,
                              :plugins => { :test => make_plugin(stage) })

      res = pr.stage({ "framework" => "test"}, @src_dir, @dst_dir)

      res[:error].should be_nil

      staged_test = File.join(@dst_dir, test_basename)
      File.exist?(staged_test).should be_true
      File.read(staged_test).should == test_contents
    end

    it "should make the manifests directory available if supplied" do
      stage =<<-EOT
      #!/bin/bash
      cat ${4}/manifest
      EOT

      mf_dir = Dir.mktmpdir
      mf_path = File.join(mf_dir, "manifest")
      mf_contents = "testing123"
      File.open(mf_path, "w+") { |f| f.write(mf_contents) }

      pr = make_plugin_runner(@plugin_config,
                              :plugins => { :test => make_plugin(stage) },
                              :manifests_dir => mf_dir)

      res = pr.stage({ "framework" => "test"}, @src_dir, @dst_dir)

      res[:error].should be_nil
      res[:log].should == mf_contents
    end

    it "should recreate symlinks for bind mounts" do
      # Set up a temporary directory housing a symlink
      base_dir = Dir.mktmpdir

      target_dir = File.join(base_dir, "linked")
      Dir.mkdir(target_dir)

      test_contents = "testing123"
      test_path = File.join(target_dir, "test")
      File.open(test_path, "w+") { |f| f.write(test_contents) }

      link_dir = File.join(base_dir, "link")
      File.symlink(target_dir, link_dir)
      linked_test_path = File.join(link_dir, "test")

      # Test that we can follow the symlink inside the container
      stage=<<-EOT
      #!/bin/bash
      cat #{linked_test_path}
      EOT

      pr = make_plugin_runner(@plugin_config,
                              :plugins => { :test => make_plugin(stage) },
                              :bind_mounts => [link_dir])

      res = pr.stage({ "framework" => "test"}, @src_dir, @dst_dir)

      res[:error].should be_nil

      res[:log].should == test_contents
    end

    it "should timeout staging if asked" do
      stage=<<-EOT
      #!/bin/bash
      sleep 5
      EOT

      # At most, how long the plugin can run for
      max_runtime = 1

      pr = make_plugin_runner(@plugin_config,
                              :plugins => { :test => make_plugin(stage) })

      res = pr.stage({ "framework" => "test"},
                     @src_dir, @dst_dir, :timeout => max_runtime)

      res[:error].should_not be_nil
      res[:error].should match(/Staging timed out/)
    end
  end

  def verify_success(result)
    result[:error].should be_nil
    result[:log].should_not be_nil
  end

  def make_plugin_runner(config, updates = {})
    VCAP::Stager::PluginRunner::WardenBased.new(config.merge(updates))
  end

  def make_plugin(stage_contents)
    root = Dir.mktmpdir

    bin_dir = File.join(root, "bin")
    Dir.mkdir(bin_dir)

    stage_script = File.join(bin_dir, "stage")
    File.open(stage_script, "w+") { |f| f.write(stage_contents) }
    FileUtils.chmod(0755, stage_script)

    root
  end

  def write_environment_script(env)
    Tempfile.open("env") do |f|
      env.each do |k, v|
        f.write("export #{k}=\"#{v}\"")
      end

      f
    end
  end
end
