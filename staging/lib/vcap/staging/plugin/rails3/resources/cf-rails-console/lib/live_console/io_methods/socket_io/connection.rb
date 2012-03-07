require 'yaml'

class LiveConsole::IOMethods::SocketIOConnection

  attr_accessor :raw_input, :raw_output

  def initialize(server, opts)
    @server = server
    @opts = opts
  end

  def start
    begin
      IO.select([@server])
      self.raw_input = self.raw_output = @server.accept
      return true
    rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO,
      Errno::EINTR => e
      select
      retry
    end
  end

  def stop
    select
    raw_input.close rescue nil
  end

  def select
    IO.select [@server], [], [], 1 if @server
  end

  # Retrieves credentials from I/O and matches them against the specified file
  # credentials_file should be of the form:
  # username: <username>
  # password: <password>
  def authenticate
    authenticated = true
    raw_output.print "Login: "
    raw_output.flush
    username = raw_input.gets
    raw_output.print "Password: "
    password = raw_input.gets
    credentials_file= @opts[:credentials_file] || '.consoleaccess'
    credentials =YAML.load_file(credentials_file)
    if username.chomp != credentials['username'] || password.chomp != credentials['password']
      raw_output.puts "Login failed."
      authenticated = false
    end
    authenticated
  end
end
