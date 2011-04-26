# Copyright (c) 2009-2011 VMware, Inc.
require 'pathname'

# Rack::Directory serves entries below the +root+ given, according to the
# path info of the Rack request. If a directory is found, the file's contents
# will be presented in an html based index. If a file is found, the env will
# be passed to the specified +app+.
#
# If +app+ is not specified, a Rack::File of the same +root+ will be used.

module DEA
  class FileServer < Rack::File
    # based on Rack::File, just add the NOFOLLOW flag
    def each
      File.open(@path, File::RDONLY | File::NOFOLLOW) { |file|
        while part = file.read(8192)
          yield part
        end
      }
    end
  end

  class Directory
    attr_reader :files
    attr_accessor :root, :path

    def initialize(root, app = nil)
      @root = Pathname.new(F.expand_path(root)).realpath
      @app = app || FileServer.new(@root)
    end

    def call(env)
      dup._call(env)
    end

    F = ::File

    def _call(env)
      @env = env
      @script_name = env['SCRIPT_NAME']
      @path_info = Rack::Utils.unescape(env['PATH_INFO'])
      @path = F.expand_path(F.join(@root, @path_info))

      resolve_symlink
      if forbidden = check_forbidden
        forbidden
      else
        list_path
      end
    end

    def resolve_symlink
      real_path = Pathname.new(@path).realpath.to_s
      return if real_path == @path

      # Adjust env only if user has access rights to real path
      app_base =  File.join(@root, @path_info.sub(/^\/+/,'').split('/').first)
      if real_path.start_with?(app_base)
        m = real_path.match(@root.to_s)
        return if m.nil?
        @env['PATH_INFO'] = @path_info = m.post_match
        @path = real_path
      end
    end

    def check_forbidden
      forbidden = false
      forbidden = true if @path_info.include? ".."
      forbidden = true if @path_info =~ /\/.+\/startup$/
      forbidden = true if @path_info =~ /\/.+\/stop$/

      # breaks BVTs
      #forbidden = true if @path_info =~ /\/.+\/run\.pid/

      # Any symlink foolishness checked here
      check_path = @path.sub(/\/\s*$/,'')
      forbidden = true if (check_path != Pathname.new(@path).realpath.to_s)
      return unless forbidden

      body = "Not accessible\n"
      size = Rack::Utils.bytesize(body)
      return [403, {"Content-Type" => "text/plain",
                "Content-Length" => size.to_s,
                "X-Cascade" => "pass"}, [body]]
    end

    def list_directory
      @files = []
      glob = F.join(@path, '*')
      root = @path_info.sub(/^\/+/,'').split('/').length <= 1

      Dir[glob].sort.each do |node|
        stat = stat(node)
        next unless stat

        basename = F.basename(node)
        # ignore B29 control files, only return defaults
        next if root && (basename != 'app' && basename != 'logs' && basename != 'tomcat')
        size = stat.directory? ? '-' : filesize_format(stat.size)
        basename << '/'  if stat.directory?
        @files << [ basename, size ]
      end

      return [ 200, {'Content-Type'=>'text/plain'}, self ]
    end

    def stat(node, max = 10)
      F.stat(node)
    rescue Errno::ENOENT, Errno::ELOOP
      return nil
    end

    # TODO: add correct response if not readable, not sure if 404 is the best
    #       option
    def list_path
      @stat = F.stat(@path)

      if @stat.readable?
        return @app.call(@env) if @stat.file?
        return list_directory if @stat.directory?
      else
        raise Errno::ENOENT, 'No such file or directory'
      end

    rescue Errno::ENOENT, Errno::ELOOP
      return entity_not_found
    end

    def entity_not_found
      body = "Entity not found.\n"
      size = Rack::Utils.bytesize(body)
      return [404, {"Content-Type" => "text/plain",
                "Content-Length" => size.to_s,
                "X-Cascade" => "pass"}, [body]]
    end

    def each
      show_path = @path.sub(/^#{@root}/,'')
      files = @files.map{|f| "%-35s %10s" % f }*"\n"
      files.each_line{|l| yield l }
    end

    # Stolen from Ramaze

    FILESIZE_FORMAT = [
                       ['%.1fT', 1 << 40],
                       ['%.1fG', 1 << 30],
                       ['%.1fM', 1 << 20],
                       ['%.1fK', 1 << 10],
                      ]

    def filesize_format(int)
      FILESIZE_FORMAT.each do |format, size|
        return format % (int.to_f / size) if int >= size
      end
      int.to_s + 'B'
    end
  end
end
