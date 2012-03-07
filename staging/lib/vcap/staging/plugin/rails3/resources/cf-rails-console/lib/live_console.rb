# LiveConsole
# Pete Elmore (pete.elmore@gmail.com), 2007-10-18
# Jennifer Hickey
# See doc/LICENSE.

require 'irb'
require 'irb/frame'
require 'socket'
require 'irb/completion'

# LiveConsole provides a socket that can be connected to via netcat or telnet
# to use to connect to an IRB session inside a running process.  It listens on the
# specified address/port or Unix Domain Socket path,
# and presents connecting clients with an IRB shell.  Using this, you can
# execute code on a running instance of a Ruby process to inspect the state or
# even patch code on the fly.
class LiveConsole
  include Socket::Constants
  autoload :IOMethods, 'live_console/io_methods'

  attr_accessor :io_method, :io, :thread, :bind, :authenticate, :readline
  private :io_method=, :io=, :thread=, :authenticate=, :readline=

  # call-seq:
  ## Bind a LiveConsole to localhost:3030 (only allow clients on this
  ## machine to connect):
  # LiveConsole.new :socket, :port => 3030
  ## Accept connections from anywhere on port 3030.  Ridiculously insecure:
  # LiveConsole.new(:socket, :port => 3030, :host => '0.0.0.0')
  ## Accept connections from anywhere on port 3030, secured with a plain-text credentials file
  ## credentials_file should be of the form:
  ### username: <username>
  ### password: <password>
  # LiveConsole.new(:socket, :port => 3030, :host => '0.0.0.0', :authenticate=>true,
  #                 :credentials_file='/path/to/.consoleaccess)
  ## Use a Unix Domain Socket (which is more secure) instead:
  # LiveConsole.new(:unix_socket, :path => '/tmp/my_liveconsole.sock',
  #	            :mode => 0600, :uid => Process.uid, :gid => Process.gid)
  ## By default, the mode is 0600, and the uid and gid are those of the
  ## current process.  These three options are for the file's permissions.
  ## You can also supply a binding for IRB's toplevel:
  # LiveConsole.new(:unix_socket,
  #		    :path => "/tmp/live_console_#{Process.pid}.sock", :bind => binding)
  #
  # Creates a new LiveConsole.  You must next call LiveConsole#start or LiveConsole#start_blocking
  # when you want to accept connections and start the console.
  def initialize(io_method, opts = {})
    self.io_method = io_method.to_sym
    self.bind = opts.delete :bind
    self.authenticate = opts.delete :authenticate
    self.readline = opts.delete :readline
    unless IOMethods::List.include?(self.io_method)
      raise ArgumentError, "Unknown IO method: #{io_method}"
    end
    init_io opts
  end

  # LiveConsole#start spawns a thread to listen for, accept, and provide an
  # IRB console to new connections.  If a thread is already running, this
  # method simply returns false; otherwise, it returns the new thread.
  def start
    if thread
      if thread.alive?
        return false
      else
        thread.join
        self.thread = nil
      end
    end

    self.thread = Thread.new {
      start_blocking
    }
    thread
  end

  # LiveConsole#start_blocking executes a loop to listen for, accept,
  # and provide an IRB console to new connections.
  # This is a blocking call and the only way to stop it is to kill the process
  def start_blocking
    loop {
      conn = io.get_connection
      #This will block until a connection is made or a failure occurs
      if conn.start
        thread = Thread.new(conn) {
          begin
            start_irb = true
            if authenticate && !conn.authenticate
              conn.stop
              start_irb = false
            end
            if start_irb
              irb_io = GenericIOMethod.new conn.raw_input, conn.raw_output, readline
              begin
                IRB.start_with_io(irb_io, bind)
              rescue Errno::EPIPE => e
                conn.stop
              end
            end
          rescue Exception => e
            puts "Error during connection: #{e.message}"
            conn.stop
          end
        }
      end
    }
  end

  # Ends the running thread, if it exists.  Returns true if a thread was
  # running, false otherwise.
  def stop
    if thread
      if thread == Thread.current
        self.thread = nil
        Thread.current.exit!
      end

      thread.exit
      if thread.join(0.1).nil?
        thread.exit!
      end
      self.thread = nil
      true
    else
      false
    end
  end

  # Restarts.  Useful for binding changes.  Return value is the same as for
  # LiveConsole#start.
  def restart
    r = lambda { stop; start }
    if thread == Thread.current
      Thread.new &r # Leaks a thread, but works.
    else
      r.call
    end
  end

  private

  def init_irb
    return if @@irb_inited_already
    IRB.setup nil
    @@irb_inited_already = true
  end

  def init_io opts
    self.io = IOMethods.send(io_method).new opts
  end
end

# We need to make a couple of changes to the IRB module to account for using a
# weird I/O method and re-starting IRB from time to time.
module IRB
  @inited = false

  ARGV = []

  # Overridden a la FXIrb to accomodate our needs.
  def IRB.start_with_io(io, bind, &block)
    unless @inited
      setup '/dev/null'
      IRB.parse_opts
      IRB.load_modules
      @inited = true
    end

    ws = IRB::WorkSpace.new(bind)

    @CONF[:PROMPT_MODE] = :DEFAULT
    #Remove the context from all prompts-can be too long depending on binding
    @CONF[:PROMPT][:DEFAULT][:PROMPT_I] = "%N():%03n:%i> "
    @CONF[:PROMPT][:DEFAULT][:PROMPT_N] = "%N():%03n:%i> "
    #Add > to S and C as they don't get picked up by telnet prompt scan
    @CONF[:PROMPT][:DEFAULT][:PROMPT_S] = "%N():%03n:%i%l> "
    @CONF[:PROMPT][:DEFAULT][:PROMPT_C] = "%N():%03n:%i*> "

    @CONF[:USE_READLINE] = false
    irb = Irb.new(ws, io, io)
    bind ||= IRB::Frame.top(1) rescue TOPLEVEL_BINDING

    @CONF[:IRB_RC].call(irb.context) if @CONF[:IRB_RC]
    @CONF[:MAIN_CONTEXT] = irb.context

    catch(:IRB_EXIT) {
      begin
        irb.eval_input
      rescue StandardError => e
        irb.print([e.to_s, e.backtrace].flatten.join("\n") + "\n")
        retry
      end
    }
    irb.print "\n"
  end

  class Context
    # Fix an IRB bug; it ignores your output method.
    def output *args
      @output_method.print *args
    end
  end

  class Irb
    # Fix an IRB bug; it ignores your output method.
    def printf(*args)
      context.output(sprintf(*args))
    end

    # Fix an IRB bug; it ignores your output method.
    def print(*args)
      context.output *args
    end
  end
end

# The GenericIOMethod is a class that wraps I/O for IRB.
class GenericIOMethod < IRB::StdioInputMethod
  # call-seq:
  # 	GenericIOMethod.new io
  # 	GenericIOMethod.new input, output
  #
  # Creates a GenericIOMethod, using either a single object for both input
  # and output, or one object for input and another for output.
  def initialize(input, output = nil, readline=false)
    @input, @output = input, output
    @line = []
    @line_no = 0
    @readline = readline
  end

  attr_reader :input
  def output
    @output || input
  end

  def gets
    output.print @prompt
    output.flush
    line = input.gets
    if @readline
      #Return tab completion data as long as we receive input that ends in '\t'
      while line.chomp =~ /\t\z/n
        run_completion_proc line.chomp.chop
        line = input.gets
      end
    end
    @line[@line_no += 1] = line
    @line[@line_no]
  end

  # Returns the user input history.
  def lines
    @line.dup
  end

  def print(*a)
    output.print *a
  end

  def file_name
    input.inspect
  end

  def eof?
    input.eof?
  end

  def encoding
    input.external_encoding
  end

  def close
    input.close
    output.close if @output
  end

  private
  # Runs the IRB CompletionProc with the given argument and writes the array to output stream as
  # a comma-separated String, terminated by newline (so clients know when all data received)
  def run_completion_proc(line)
    opts = IRB::InputCompletor::CompletionProc.call(line)
    opts.compact!
    optstrng = opts.join(",") + "\n"
    output.print optstrng
    output.flush
  end
end
