$:.unshift(File.join(File.dirname(__FILE__)))
require 'tmpdir'
require 'lib/user_ops'
require 'lib/run_as'

class GemBuilder
  def initialize(uid, build_dir, gem_name)
    @uid = uid
    @build_dir = build_dir
    @gem_name = gem_name
    #test for existence of build_dir
    #test for existence of gem
  end

  def build_gem!
    install_dir = Dir.mktmpdir(nil, build_dir)
    run_as(@build_dir, @uid, "gem install #{gem_path} --local --no-rdoc --no-ri -E -w -f --ignore-dependencies --install-dir #{install_dir}")

    package_file = gem_to_package(base_gem)
    run(@build_dir, @uid, "tar czf #{package_file} #{install_dir}")
  end
end
