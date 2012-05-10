$:.unshift(File.join(File.dirname(__FILE__)))
require 'logger'
require 'pkg_util'
require 'pkg_build'

module VCAP module PackageCache end end

class VCAP::PackageCache::GemBuild < VCAP::PackageCache::PkgBuild
  def initialize(buildenv, runtime, logger = nil)
    super(buildenv, logger)
    @logger = logger || Logger.new(STDOUT)
    @buildenv = buildenv
    @bin_path = buildenv.bin_path(runtime)
    @logger.debug("new gem build initialized.")
  end

  def report_build_status(target, status, output)
    if status != 0
      @logger.debug("gem install #{target} command failed \n <<<BEGIN ERROR OUTPUT>>>: #{output} <<<END ERROR OUTPUT>>>")
      raise "gem install #{target} failed, exist status: #{status} (enable debug logging for details)."
    else
      @logger.debug("gem install #{target} command succeeded.")
    end
  end

  def build_gem(location, gem_name)
    gem_cmd_path = File.join(@bin_path, 'gem')
    ruby_cmd_path = File.join(@bin_path, 'ruby')

    if location == :local
      raise "no src_path set, first import package for local build" unless @src_path
      install_target = @src_path
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
    status, out, err = @buildenv.run("#{build_cmd} #{build_opts} #{@install_dir}")
    report_build_status(gem_name, status, out + err)
  end

  def build(location, name)
    @logger.info("building #{location} package #{name}")
    build_gem(location, name)
  end

end
