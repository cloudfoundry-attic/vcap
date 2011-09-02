require 'tmpdir'

require 'vcap/em_run'

require 'pkg_util'
require 'builder'

module VCAP module PackageCache end end

class VCAP::PackageCache::GemBuilder < VCAP::PackageCache::Builder
  def initialize(user, build_root, logger = nil)
    super(user, build_root, logger)
    VCAP::EMRun.init(@logger)
    @logger.debug("new gem_builder with uid: #{@user[:uid]} build_root #{build_root}")
  end

  def setup_build
    @install_dir = Dir.mktmpdir(nil, @build_dir)
    grant_ownership(@install_dir)
  end

  def verify_install(target)
    raise "gem install failed!" if not File.exist? File.join(@install_dir, 'gems')
    @logger.debug("gem install of #{target} to #{@install_dir} complete.")
  end

  def report_build_status(target, status, output)
    if status != 0
      @logger.debug("gem install #{target} command failed \n <<<BEGIN ERROR OUTPUT>>>: #{output} <<<END ERROR OUTPUT>>>")
      raise "gem install #{target} failed, exist status: #{status} (enable debug logging for details)."
    else
      @logger.debug("gem install #{target} command succeeded.")
    end
  end

  def build_local(gem_name, gem_path)
    output, status = VCAP::EMRun.run_restricted(@build_dir, @user,
        "gem install #{gem_path} --local --no-rdoc --no-ri -E -w -f --ignore-dependencies --install-dir #{@install_dir}")
    report_build_status(gem_name, status, output)
    verify_install(gem_path)
  end

  def gem_to_url(gem_name)
    "http://production.s3.rubygems.org/gems/#{gem_name}"
  end

  def fetch_remote_gem(gem_name)
    url = gem_to_url(gem_name)
    @logger.debug("fetching #{gem_name}")
    download_cmd = "wget --quiet --retry-connrefused --connect-timeout=5 --no-check-certificate #{url}"
    output, status = VCAP::EMRun.run_restricted(@build_dir, @user, download_cmd)
    if status != 0
      @logger.error "Download failed with status #{status}"
      @logger.error output
    end
    raise "Download failed" if not File.exists?(File.join(@build_dir, gem_name))
  end

  def package_gem(gem_name)
    package_file = PkgUtil.to_package(gem_name)
    output, status = VCAP::EMRun.run_restricted(@install_dir, @user,
                                           "tar czf #{package_file} gems")
    if status != 0
      raise "tar czf #{package_file} failed> exist status: #{status}, output: #{output}"
    end
    package_path = File.join(@install_dir, package_file)
    raise "package build failed!" if not File.exist? package_path
    package_path
  end

  def build(location, name, path = nil)
    @logger.info("building #{location.to_s} package #{name}")
    setup_build
    if location == :local
      import_package_src(path)
      build_local(@src_name, @src_path)
    else
      fetch_remote_gem(name)
      build_local(name, File.join('.', name))
    end
    @package_path = package_gem(name)
    @logger.debug("created package #{@package_path}.")
  end

end
