require 'tmpdir'

require 'pkg_util'
require 'builder'
require 'run'

module VCAP module PackageCache end end

class VCAP::PackageCache::GemBuilder < VCAP::PackageCache::Builder
  def initialize(user, build_root, runtimes, logger = nil)
    super(user, build_root, runtimes, logger)
    @logger.debug("new gem_builder with uid: #{@user[:uid]} build_root #{build_root}")
  end

  def verify_install(target)
    raise "gem install failed!" unless verify_exists? File.join(@install_dir, 'gems')
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

  def build_gem(location, gem_name, gem_path, bin_path)
    gem_cmd_path = File.join(bin_path, 'gem')
    ruby_cmd_path = File.join(bin_path, 'ruby')

    if location == :local
      install_target = gem_path
      gem_location = "--local"
    else
      tokens = PkgUtil.drop_extension(gem_name).split('-')
      base_name = tokens[0..-2].join('-')
      version = tokens[-1]
      gem_location = ""
      install_target = "#{base_name} --version #{version}"
    end

    build_cmd = "#{ruby_cmd_path} #{gem_cmd_path} install #{install_target}"
    build_opts = "#{gem_location} --no-rdoc --no-ri -E -w -f --ignore-dependencies --install-dir"
    output, status = Run.run_restricted(@build_dir, @user,
                                    "#{build_cmd} #{build_opts} #{@install_dir}")
    report_build_status(gem_name, status, output)
    verify_install(gem_path)
  end

  def build(location, name, path, runtime)
    @logger.info("building #{location} package #{name} for runtime #{runtime}")
    ruby_path = @runtimes[runtime]
    bin_path = File.dirname(ruby_path)
    if location == :local
      import_package_src(path)
      build_gem(location, @src_name, @src_path, bin_path)
    else
      build_gem(location, name, nil, bin_path)
    end
    @package_path = create_package(name, runtime)
    @logger.debug("created package #{@package_path}.")
  end

end
