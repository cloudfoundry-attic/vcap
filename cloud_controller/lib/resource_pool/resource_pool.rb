require 'timed_section'
# A "resource" is typically represented as a Hash with two attributes:
# :size (bytes)
# :sha1 (string)
# If there are other attributes, such as in legacy calls to 'match_resources',
# they will be ignored and preserved.
#
# See config/initializers/resource_pool.rb for where this is initialized
# in production mode.
# See spec/spec_helper.rb for the test initialization.
#
# TODO - Implement 'Blob Store' subclass.
class ResourcePool
  attr_accessor :minimum_size, :maximum_size

  def initialize(options)
    @options = options || {}
    @minimum_size = @options[:minimum_size] || 0.bytes
    @maximum_size = @options[:maximum_size] || 512.megabytes
  end

  def logger
    CloudController.logger
  end

  def match_resources(descriptors)
    return [] unless Array === descriptors
    timed_section(logger, 'match_resources') do
      descriptors.select do |hash|
        resource_known?(hash)
      end
    end
  end

  def resource_known?(descriptor)
    raise NotImplementedError, "Implemented in subclasses. See filesystem.rb for example."
  end

  # Adds everything under source directory +dir+ to the resource pool.
  def add_directory(dir)
    unless File.exists?(dir) && File.directory?(dir)
      raise ArgumentError, "Source directory #{dir} is not valid"
    end
    timed_section(logger, 'add_directory') do
      pattern = File.join(dir, '**', '*')
      Dir.glob(pattern, File::FNM_DOTMATCH).each do |path|
        add_path(path)
      end
    end
  end

  # Reads +path+ from the local disk and adds it to the pool, if needed.
  def add_path(path)
    raise NotImplementedError, "Implement in each subclass"
  end

  def copy(descriptor, destination)
    if resource_known?(descriptor)
      overwrite_destination_with!(descriptor, destination)
    else
      raise ArgumentError, "Can't copy bits we don't have"
    end
  end

  private

  # Returns a path for the specified resource.
  def path_from_sha1(sha1)
    raise NotImplementedError, 'Implemented in subclasses. See filesystem_pool for example.'
  end

  # Called after we sanity-check the input.
  # Create a new path on disk containing the resource described by +descriptor+
  def overwrite_destination_with!(descriptor, destination)
    raise NotImplementedError, 'Implemented in subclasses. See filesystem_pool for example.'
  end
end
