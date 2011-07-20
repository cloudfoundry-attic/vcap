require "digest/sha1"
require "fileutils"
require "tempfile"
require "tmpdir"

class GemCache

  def initialize(directory)
    @directory  = directory
  end

  def put(gemfile_path, installed_gem_path)
    return unless gemfile_path && File.exists?(gemfile_path)
    return unless installed_gem_path && File.exists?(installed_gem_path)

    dst_dir = cached_obj_dir(gemfile_path)

    spec_dir = File.join(dst_dir, "specifications")
    FileUtils.mkdir_p(spec_dir)

    `cp -n #{installed_gem_path}/specifications/*.gemspec #{spec_dir}`
    # Someone else is copying gem?
    return installed_gem_path if $?.exitstatus != 0

    `cp -a #{installed_gem_path}/* #{dst_dir} && touch #{dst_dir}/.done`
    return installed_gem_path if $?.exitstatus != 0
    dst_dir
  end

  def get(path)
    return nil unless path && File.exists?(path)
    dir = cached_obj_dir(path)
    return nil if !File.exists?(File.join(dir, ".done"))
    File.directory?(dir) ? dir : nil
  end

  private

  def cached_obj_dir(path)
    sha1 = Digest::SHA1.file(path).hexdigest
    "%s/%s/%s/%s" % [ @directory, sha1[0..1], sha1[2..3], sha1[4..-1] ]
  end

end
