require 'fileutils'
require 'net/http'
require 'uri'

require 'vcap/common'

module VCAP
  module Stager
  end
end

module VCAP::Stager::Util
  class HttpStatusError < StandardError; end

  class IOBuffer
    attr_reader :size

    def initialize(*ios)
      @ios        = ios.dup
      @io_off     = 0
      @stream_off = 0
      @size       = @ios.reduce(0) {|sum, io| sum + io.size }
    end

    def read(nbytes_left=nil, dst=nil)
      ret = nil
      nbytes_left ||= @size - @stream_off
      while (@io_off < @ios.length) && (nbytes_left > 0)
        cur_io = @ios[@io_off]
        tbuf = cur_io.read(nbytes_left)
        if tbuf == nil
          # EOF encountered, no bytes read. This can happen
          # if a previous read read exactly the number of bytes remaining for the io.
          @io_off += 1
        else
          if ret
            ret += tbuf
          else
            ret = tbuf
          end
          # EOF encountered after reading > 0 bytes.
          @io_off += 1 if tbuf.length < nbytes_left
          @stream_off += tbuf.length
          nbytes_left -= tbuf.length
        end
      end
      dst += ret if dst
      ret
    end

    def rewind
      @io_off = 0
      @stream_off = 0
      @ios.each {|io| io.rewind }
    end

  end

  class MultipartFileStream
    attr_reader :boundary, :size, :header, :footer

    def initialize(fieldname, file)
      @boundary  = VCAP.secure_uuid
      @fieldname = fieldname
      @header    = make_header(@boundary, fieldname, File.basename(file.path))
      @footer    = make_footer(@boundary)
      @io_buf    = VCAP::Stager::Util::IOBuffer.new(@header, file, @footer)
      @size      = @io_buf.size
    end

    def read(*args)
      @io_buf.read(*args)
    end

    def size
      @io_buf.size
    end

    private

    def make_header(boundary, fieldname, filename)
      hdr =  "--#{boundary}\r\n"
      hdr += "Content-Disposition: form-data; name=\"#{fieldname}\"; filename=\"#{filename}\"\r\n"
      hdr += "Content-Type: application/octet-stream\r\n"
      hdr += "\r\n"
      StringIO.new(hdr)
    end

    def make_footer(boundary)
      StringIO.new("\r\n--#{boundary}--\r\n")
    end
  end

  class << self
    # Downloads the zipped app living at _app_uri_ and stores it in a temporary file.
    #
    # NB: This streams the file to disk.
    #
    # @param   app_uri    String   Uri where one can fetch the app. Credentials should be included
    #                              in the uri (i.e. 'http://user:pass@www.foo.com/bar.zip')
    # @param   dest_path  String   Where the app should be saved on disk
    def fetch_zipped_app(app_uri, dest_path)
      uri = URI.parse(app_uri)
      req = make_request(Net::HTTP::Get, uri)

      File.open(dest_path, 'wb+') do |f|
        Net::HTTP.start(uri.host, uri.port) do |http|
          http.request(req) do |resp|
            resp.read_body do |chunk|
              f.write(chunk)
            end
            # Throws if non-200
            resp.value
          end
        end
      end

    rescue
      FileUtils.rm_f(dest_path)
      raise
    end

    # Uploads the file living at _droplet_path_ to the uri using a PUT request.
    #
    # NB: This streams the file off of disk.
    #
    # @param  uri           String  Where the app should be uploaded to
    # @param  droplet_path  String  The location on disk of the droplet to be uploaded
    def upload_droplet(droplet_uri, droplet_path)
      uri  = URI.parse(droplet_uri)
      req  = make_request(Net::HTTP::Post, uri)
      droplet = File.open(droplet_path)
      mpfs = MultipartFileStream.new('upload[droplet]', droplet)
      req.content_length = mpfs.size
      req.set_content_type('multipart/form-data', :boundary => mpfs.boundary)
      req.body_stream = mpfs

      ret = Net::HTTP.start(uri.host, uri.port) do |http|
        http.request(req)
      end

      # Throws if non-200
      ret.value
    ensure
      droplet.close if droplet
    end


    # Runs a command in a subprocess with an optional timeout. Captures stdout, stderr.
    # Not the prettiest implementation, but neither EM.popen nor EM.system exposes
    # a way to capture stderr..
    #
    # NB: Must be called with the EM reactor running.
    #
    # @param command              String  Command to execute
    # @param expected_exitstatus  Integer
    # @param timeout              Integer How long the command can execute for
    # @param blk                  Block   Callback to execute when the command completes. It will
    #                                     be called with a hash of:
    #                                     :success    Bool      True if the command exited with expected status
    #                                     :stdout     String
    #                                     :stderr     String
    #                                     :status     Integer
    #                                     :timed_out  Bool
    def run_command(command, expected_exitstatus=0, timeout=nil, &blk)
      expire_timer   = nil
      timed_out      = false
      stderr_tmpfile = Tempfile.new('stager_stderr')
      stderr_path    = stderr_tmpfile.path
      stderr_tmpfile.close

      pid = EM.system('sh', '-c', "#{command} 2> #{stderr_path}") do |stdout, status|
        EM.cancel_timer(expire_timer) if expire_timer

        begin
          stderr = File.read(stderr_path)
          stderr_tmpfile.unlink
        rescue => e
          logger = VCAP::Logging.logger('vcap.stager.task.run_command')
          logger.error("Failed reading stderr from '#{stderr_path}' for command '#{command}': #{e}")
          logger.error(e)
        end

        res = {
          :success   => status.exitstatus == expected_exitstatus,
          :stdout    => stdout,
          :stderr    => stderr,
          :status    => status,
          :timed_out => timed_out,
        }

        blk.call(res)
      end

      if timeout
        expire_timer = EM.add_timer(timeout) do
          logger = VCAP::Logging.logger('vcap.stager.task.expire_command')
          logger.warn("Killing command '#{command}', pid=#{pid}, timeout=#{timeout}")
          timed_out = true
          EM.system('sh', '-c', "ps --ppid #{pid} -o pid= | xargs kill -9")
        end
      end
    end

    private

    # Creates an instance of a class derived from Net::HTTPRequest
    # and sets basic auth info
    #
    # @param  klass  Net::HTTPRequest
    # @param  uri    URI::HTTP
    #
    # @return Net::HTTPRequest
    def make_request(klass, uri)
      req = klass.new(uri.request_uri)
      if uri.user
        req.basic_auth(uri.user, uri.password)
      end
      req
    end
  end
end
