# Copyright (c) 2009-2011 VMware, Inc.
require 'fileutils'
require 'socket'

# VMware's Cloud Application Platform

module VCAP

  A_ROOT_SERVER = '198.41.0.4'

  def self.local_ip(route = A_ROOT_SERVER)
    route ||= A_ROOT_SERVER
    orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
    UDPSocket.open {|s| s.connect(route, 1); s.addr.last }
  ensure
    Socket.do_not_reverse_lookup = orig
  end

  def self.secure_uuid
    result = File.open('/dev/urandom') { |x| x.read(16).unpack('H*')[0] }
  end

  def self.grab_ephemeral_port
    socket = TCPServer.new('0.0.0.0', 0)
    socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
    Socket.do_not_reverse_lookup = true
    port = socket.addr[1]
    socket.close
    return port
  end

  def self.uptime_string(delta)
    num_seconds = delta.to_i
    days = num_seconds / (60 * 60 * 24);
    num_seconds -= days * (60 * 60 * 24);
    hours = num_seconds / (60 * 60);
    num_seconds -= hours * (60 * 60);
    minutes = num_seconds / 60;
    num_seconds -= minutes * 60;
    "#{days}d:#{hours}h:#{minutes}m:#{num_seconds}s"
  end

  def self.num_cores
    if RUBY_PLATFORM =~ /linux/
      return `cat /proc/cpuinfo | grep processor | wc -l`.to_i
    elsif RUBY_PLATFORM =~ /darwin/
      `hwprefs cpu_count`.strip.to_i
    elsif RUBY_PLATFORM =~ /freebsd|netbsd/
      `sysctl hw.ncpu`.strip.to_i
    else
      return 1 # unknown..
    end
  rescue
    # hwprefs doesn't always exist, and so the block above can fail.
    # In any case, let's always assume that there is 1 core
    1
  end

  def self.defer(*args, &blk)
    if args[0].kind_of?(Hash)
      op = blk
      opts = args[0]
    else
      op = args[0] || blk
      opts = args[1] || {}
    end

    callback = opts[:callback]
    logger = opts[:logger]
    nobacktrace = opts[:nobacktrace]

    wrapped_operation = exception_wrap_block(op, logger, nobacktrace)
    wrapped_callback = callback ? exception_wrap_block(callback, logger, nobacktrace) : nil
    EM.defer(wrapped_operation, wrapped_callback)
  end

  def self.exception_wrap_block(op, logger, nobacktrace=false)
    Proc.new do |*args|
      begin
        op.call(*args)
      rescue => e
        err_str = "#{e} - #{e.backtrace.join("\n")}" unless nobacktrace
        err_str = "#{e}" if nobacktrace
        if logger
          logger.fatal(err_str)
        else
          $stderr.puts(err_str)
        end
      end
    end
  end

  def self.process_running?(pid)
    return false unless pid && (pid > 0)
    output = %x[ps -o rss= -p #{pid}]
    return true if ($? == 0 && !output.empty?)
    # fail otherwise..
    return false
  end

  def self.pp_bytesize(bsize)
    units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB']
    base  = 1000
    bsize = bsize.to_f()
    quotient = unit = nil
    units.each_with_index do |u, i|
      unit = u
      quotient = bsize / (base ** i)
      break if quotient < base
    end
    "%0.2f%s" % [quotient, unit]
  end

  def self.symbolize_keys(hash)
    if hash.is_a? Hash
      new_hash = {}
      hash.each {|k, v| new_hash[k.to_sym] = symbolize_keys(v) }
      new_hash
    else
      hash
    end
  end

  # Helper class to atomically create/update pidfiles and ensure that only one instance of a given
  # process is running at all times.
  #
  # NB: Ruby doesn't have real destructors so if you want to be polite and clean up after yourself
  # be sure to call unlink() before your process exits.
  #
  # usage:
  #
  # begin
  #   pidfile = VCAP::PidFile.new('/tmp/foo')
  # rescue => e
  #   puts "Error creating pidfile: %s" % (e)
  #   exit(1)
  # end
  class PidFile
    class ProcessRunningError < StandardError
    end

    def initialize(pid_file, create_parents=true)
      @pid_file = pid_file
      @dirty = true
      write(create_parents)
    end

    # Removes the created pidfile
    def unlink()
      return unless @dirty

      # Swallowing exception here is fine. Removing the pid files is a courtesy.
      begin
        File.unlink(@pid_file)
        @dirty = false
      rescue
      end
      self
    end

    # Removes the created pidfile upon receipt of the supplied signals
    def unlink_on_signals(*sigs)
      return unless @dirty

      sigs.each do |s|
        Signal.trap(s) { unlink() }
      end
      self
    end

    def unlink_at_exit()
      at_exit { unlink() }
      self
    end

    def to_s()
      @pid_file
    end

    protected

    # Atomically writes the pidfile.
    # NB: This throws exceptions if the pidfile contains the pid of another running process.
    #
    # +create_parents+  If true, all parts of the path up to the file's dirname will be created.
    #
    def write(create_parents=true)
      FileUtils.mkdir_p(File.dirname(@pid_file)) if create_parents

      # Protip from Wilson: binary mode keeps things sane under Windows
      # Closing the fd releases our lock
      File.open(@pid_file, 'a+b', 0644) do |f|
        f.flock(File::LOCK_EX)

        # Check if process is already running
        pid = f.read().strip().to_i()
        if pid == Process.pid()
          return
        elsif VCAP.process_running?(pid)
          raise ProcessRunningError.new("Process already running (pid=%d)." % (pid))
        end

        # We're good to go, write our pid
        f.truncate(0)
        f.rewind()
        f.write("%d\n" % (Process.pid()))
        f.flush()
      end
    end
  end # class PidFile

end # module VCAP

# Make the patch here for proper bytesize
if RUBY_VERSION <= "1.8.6"
  class String #:nodoc:
    def bytesize; self.size; end
  end
end

# FIXME, we should ditch ruby logger.
# Monkey Patch to get rid of some deadlocks under load in CC, make it available for all.

require 'logger'

STDOUT.sync = true

class Logger::LogDevice
  def write(message)
    @dev.syswrite(message)
  end

  def close
    @dev.close
  end
end
