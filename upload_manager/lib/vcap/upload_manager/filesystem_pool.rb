$:.unshift(File.dirname(__FILE__))
require 'resource_pool'
require 'fileutils'
require 'digest/sha1'

module VCAP module UploadManager end end

class VCAP::UploadManager::FilesystemPool < VCAP::UploadManager::ResourcePool

  def initialize(pool_root, logger = nil)
    @logger = logger || Logger.new(STDOUT)
    super(@logger)
    unless Dir.exists? pool_root
      raise ArgumentError, "invalid resource pool dir: #{pool_root}"
    end
    @pool_root = pool_root
    # Defaults give over 2B objects, given 32k limit per directory for files.
    # Files look like /shared/resources/MOD#1/MOD#2/SHA1
    @levels    = 2
    @modulos   = [269, 251]
    unless @modulos.size == @levels
      raise ArgumentError, 'modulos array must have one entry per level'
    end
    @logger.debug("Initialized filesystem pool.")
  end

  def contains?(descriptor)
    resource_path = path_from_sha1(descriptor[:sha1])
    File.exists?(resource_path) and File.size(resource_path) == descriptor[:size].to_i
  end

  def valid_file?(path)
     file = File.stat(path)
     not ((file.directory? || file.symlink?) or
          (file.size < @minimum_size) or
          (file.size > @maximum_size))
  end

  def file_to_descriptor(path)
     size = File.stat(path).size
     sha1 = Digest::SHA1.file(path).hexdigest
     {:sha1 => sha1, :size => size}
  end

  def add_path(path)
    return false if not valid_file?(path)
    d = file_to_descriptor(path)
    resource_path = path_from_sha1(d[:sha1])
    return false if File.exists?(resource_path)
    FileUtils.mkdir_p File.dirname(resource_path)
    FileUtils.cp(path, resource_path)
    true
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
    @levels.times do |i|
      dirs << as_integer.modulo(@modulos[i]).to_s
    end
    dir = File.join(@pool_root, *dirs)
    File.join(dir, sha1)
  end
end
