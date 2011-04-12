require 'resource_pool/filesystem_pool'

unless Rails.env.test?
  pool = FilesystemPool.new(:directory => AppConfig[:directories][:resources])
  CloudController.resource_pool = pool
end
