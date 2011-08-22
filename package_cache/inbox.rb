$:.unshift(File.join(File.dirname(__FILE__),'../../common/lib'))
$:.unshift(File.join(File.dirname(__FILE__)))
require 'logger'
require 'lib/vdebug'
require 'digest/sha1'
require 'vcap/subprocess'

module PackageCache
  class Inbox
    def initialize(inbox_dir, type, logger = nil)
      @logger = logger || Logger.new(STDOUT)
      @inbox_dir = inbox_dir
      set_inbox_permissions if not type == :client
    end

    def get_entry(name)
      path = get_entry_path(name)
      return nil if not File.exists?(path)
      path
    end

    def secure_import_entry(name)
      raise "entry hash does not match contents!" if not verify_entry_hash(name)
      raise "file in use, cannot be imported" if not verify_no_file_users(name)
      set_entry_permissions(name)
    end

    def contains?(name)
      File.exists? get_entry_path(name)
    end

    def add_entry(src_path)
      content_hash = Digest::SHA1.file(src_path).hexdigest
      extension = File.extname(src_path)
      entry_name = "#{content_hash}#{extension}"
      @logger.debug("adding #{src_path} to inbox as #{entry_name}")
      FileUtils.cp src_path, File.join(@inbox_dir, entry_name)
      entry_name

    end

    def purge!
      @logger.debug("purging inbox directory #{@inbox_dir}")
      FileUtils.rm_f Dir.glob("#{@inbox_dir}/*")
    end

    private

    def get_entry_path(name)
      File.join(@inbox_dir, name)
    end

    def set_entry_permissions(name)
      path = get_entry_path(name)
      File.chown(Process.uid, Process.gid, path)
      #when we import an entry, deny anyone but the cache access to it.
      File.chmod(0700, path)
    end

    def set_inbox_permissions
      File.chown(Process.uid, Process.gid, @inbox_dir)
      #clients can write to inbox, but not overwrite others files.
      File.chmod(01722, @inbox_dir)
    end

    def verify_entry_hash(name)
      path = get_entry_path(name)
      name_hash,_ = File.basename(name,'.*')
      content_hash = Digest::SHA1.file(path).hexdigest
      content_hash == name_hash
    end

    def verify_no_file_users(name)
      path = get_entry_path(name)
      begin
      #XXX something wonky with subprocess run, expected_exist_status should be 1
      result = VCAP::Subprocess.new.run("fuser #{path}", 256)
      rescue => e
         @logger.warn("file #{path} is in use by: #{e.stdout}, not safe to import!!")
         return false
      end
      true
    end
  end
end
