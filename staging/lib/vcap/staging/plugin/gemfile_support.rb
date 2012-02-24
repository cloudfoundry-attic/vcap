module GemfileSupport

  # OK, so this is our workhorse.
  # 1. If file has no Gemfile.lock we never attempt to outsmart it, just stage it as is.
  # 2. If app has been a subject to 'bundle install --local --deployment' we ignore it as
  #    user seems to be confident it just work in the environment he pushes into.
  # 3. If app has been 'bundle package'd we attempt to compile and cache its gems so we can
  #    bypass compilation on the next staging (going to step 4 for missing gems).
  # 4. If app just has Gemfile.lock, we fetch gems from Rubygems and cache them locally, then
  #    compile them and cache compilation results (using the same cache as in step 3).
  # 5. Finally we just copy all these files back to a well-known location the app honoring
  #    Rubygems path structure.
  # NB: ideally this should be refactored into a set of saner helper classes, as it's really
  # hard to follow who calls what and where.
  def compile_gems
    @rack = true
    @thin = true

    return unless uses_bundler?
    return if packaged_with_bundler_in_deployment_mode?

    safe_env = [ "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "C_INCLUDE_PATH", "LIBRARY_PATH" ].map { |e| "#{e}='#{ENV[e]}'" }.join(" ")
    path     = [ "/bin", "/usr/bin", "/sbin", "/usr/sbin"]
    path.unshift(File.dirname(ruby)) if ruby[0] == '/'

    safe_env << " PATH='%s'" % [ path.uniq.join(":") ]
    safe_env << " LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8"
    base_dir = StagingPlugin.platform_config["cache"]

    app_dir  = File.join(destination_directory, 'app')
    ruby_cmd = "env -i #{safe_env} #{ruby}"

    @task = GemfileTask.new(app_dir, library_version, ruby_cmd, base_dir, @staging_uid, @staging_gid)

    @task.install
    @task.install_bundler
    @task.remove_gems_cached_in_app

    @rack = @task.bundles_rack?
    @thin = @task.bundles_thin?

    write_bundle_config
  end

  def library_version
    environment[:runtime] == "ruby19" ? "1.9.1" : "1.8"
  end

  # Can we expect to run this app on Rack?
  def rack?
    @rack
  end

  # Can we expect to run this app on Thin?
  def thin?
    @thin
  end

  def uses_bundler?
    File.exists?(File.join(source_directory, 'Gemfile.lock'))
  end

  def bundles_gem?(gem_name)
    @task.bundles_gem? gem_name
  end

  def packaged_with_bundler_in_deployment_mode?
    File.directory?(File.join(source_directory, 'vendor', 'bundle', library_version))
  end

  def install_local_gem(gem_dir,gem_filename,gem_name,gem_version)
    @task.install_local_gem gem_dir,gem_filename,gem_name,gem_version
  end

  def install_gems(gems)
    @task.install_gems gems
  end

  # This sets a relative path to the bundle directory, so nothing is confused
  # after the app is unpacked on a DEA.
  def write_bundle_config
    config = <<-CONFIG
---
BUNDLE_PATH: rubygems
BUNDLE_DISABLE_SHARED_GEMS: "1"
BUNDLE_WITHOUT: test
    CONFIG
    dot_bundle = File.join(destination_directory, 'app', '.bundle')
    FileUtils.mkdir_p(dot_bundle)
    File.open(File.join(dot_bundle, 'config'), 'wb') do |config_file|
      config_file.print(config)
    end
  end
end

