$:.unshift(File.join(File.dirname(__FILE__)))
require 'logger'
require 'lib/vdebug'

module PackageCache
  class Inbox
    def initialize(inbox_dir, type, logger = nil)
      @logger = logger || Logger.new(STDOUT)
      @inbox_dir = inbox_dir
      set_inbox_permissions if not type == :client
    end

    def get_entry(name)
      path = entry_path(name)
      return nil if not File.exists?(path)
      path
    end

    def contains?(name)
      File.exists? entry_path(name)
    end

    def add_entry(src_path)
      @logger.debug("adding #{src_path} to inbox")
      FileUtils.cp src_path, @inbox_dir
      true
    end

    def purge!
      FileUtils.rm_f Dir.glob("#{@inbox_dir}/*")
    end

    private

    def entry_path(name)
      File.join(@inbox_dir, name)
    end

    def set_inbox_permissions
      File.chown(Process.uid, Process.gid, @inbox_dir)
      #clients can write to inbox, but not overwrite others files.
      File.chmod(01722, @inbox_dir)
    end
  end
end
