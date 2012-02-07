require 'resource_pool/resource_pool'
require 'fileutils'
require 'tmpdir'

class FilesystemPool < ResourcePool
  attr_accessor :directory, :levels, :modulos

  def initialize(options = nil)
    super
    @directory = @options[:directory] || Dir.mktmpdir.to_s
    # Defaults give over 2B objects, given 32k limit per directory for files.
    # Files look like /shared/resources/MOD#1/MOD#2/SHA1
    @levels    = @options[:levels] || 2
    @modulos   = @options[:modulos] || [269, 251]
    unless @modulos.size == @levels
      raise ArgumentError, 'modulos array must have one entry per level'
    end
  end

  def resource_known?(descriptor)
    return false unless Hash === descriptor
    resource_path = path_from_sha1(descriptor[:sha1])
    if File.exists?(resource_path)
      File.size(resource_path) == descriptor[:size].to_i
    end
  end

  def add_path(path)
    file = File.stat(path)
    return if file.directory? || file.symlink?
    return if file.size < minimum_size
    return if file.size > maximum_size
    sha1 = Digest::SHA1.file(path).hexdigest
    resource_path = path_from_sha1(sha1)
    return if File.exists?(resource_path)
    FileUtils.mkdir_p File.dirname(resource_path)
    FileUtils.cp(path, resource_path)
    true
  end

  def resource_sizes(resources)
    sizes = []
    resources.each do |descriptor|
      resource_path = path_from_sha1(descriptor[:sha1])
      if File.exists?(resource_path)
        entry = descriptor.dup
        entry[:size] = File.size(resource_path)
        sizes << entry
      end
    end
    sizes
  end

  private

  def overwrite_destination_with!(descriptor, destination)
    FileUtils.mkdir_p File.dirname(destination)
    resource_path = path_from_sha1(descriptor[:sha1])
    FileUtils.cp(resource_path, destination)
  end

  def path_from_sha1(sha1)
    sha1 = sha1.to_s.downcase
    as_integer = Integer("0x#{sha1}")
    dirs = []
    levels.times do |i|
      dirs << as_integer.modulo(modulos[i]).to_s
    end
    dir = File.join(directory, *dirs)
    File.join(dir, sha1)
  end
end
