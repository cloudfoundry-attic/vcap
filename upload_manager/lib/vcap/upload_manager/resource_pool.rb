require 'logger'

module VCAP module UploadManager end end

class VCAP::UploadManager::ResourcePool
  def initialize(logger = nil)
    @logger = logger || Logger.new(STDOUT)
    @maximum_size = 512 * 1024 * 1024 #512 megabytes
    @minimum_size = 0
  end

  def match_resources(descriptors)
    @logger.debug("querying resource pool with:#{descriptors.to_s}")
    descriptors.select do |d|
      contains?(d)
    end
  end

  #returns true if descriptor in pool.
  def contains?(descriptor)
    raise NotImplementedError, "Must be implemented in subclass."
  end

  # Reads +path+ from the local disk and adds it to the pool, if needed.
  def add_path(path)
    raise NotImplementedError, "Implement in subclasses."
  end

  def add_directory(src_dir)
    unless Dir.exists?(src_dir)
      raise ArgumentError, "Source directory #{src_dir} is not valid"
    end
    pattern = File.join(src_dir, '**', '*')
    Dir.glob(pattern, File::FNM_DOTMATCH).each do |path|
      add_path(path)
    end
  end

  def retrieve_file(descriptor, dst_path)
    if contains?(descriptor)
      overwrite_destination_with!(descriptor, dst_path)
    else
      raise ArgumentError, "Couldn't find #{descriptor.to_s} in pool"
    end
  end

  private

  def overwrite_destination_with!(descriptor, destination)
    raise NotImplementedError, 'Implemented in subclasses.'
  end
end


