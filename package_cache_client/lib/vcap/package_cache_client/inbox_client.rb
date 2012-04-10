require 'fileutils'
require 'logger'
require 'digest/sha1'

module VCAP module PackageCacheClient end end

class VCAP::PackageCacheClient::InboxClient
  def initialize(inbox_root, logger = nil)
    @logger = logger || Logger.new(STDOUT)
    raise "Invalid inbox root #{inbox_root}" if not Dir.exists? inbox_root
    @inbox_public = File.join(inbox_root, 'public')
    raise "Invalid public inbox" unless Dir.exists? @inbox_public
  end

  def file_to_entry_name(path)
    content_hash = Digest::SHA1.file(path).hexdigest
    extension = File.extname(path)
    entry_name = "#{content_hash}#{extension}"
  end

  def public_contains?(name)
    File.exists?(File.join(@inbox_public, name))
  end

  def add_entry(src_path)
    entry_name = file_to_entry_name(src_path)
    if public_contains?(entry_name)
      raise "file named #{entry_name} already in inbox"
    end
    @logger.debug("adding #{src_path} to inbox as #{entry_name}")
    FileUtils.cp src_path, File.join(@inbox_public, entry_name)
    entry_name
  end
end


