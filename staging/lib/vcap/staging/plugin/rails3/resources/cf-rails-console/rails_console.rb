# Add lib directory to the load path
$: << "#{File.dirname(__FILE__)}/lib"

require 'live_console'

class RailsConsole

  def initialize(opts)
    @host = opts[:host]
    @port = opts[:port]
    @credentials_file = opts[:credentials_file]
    initialize_rails_env
  end

  def start
    puts "Starting console on port #{@port}..."
    lc = LiveConsole.new(:socket, :port => @port, :host => @host, :bind => binding,
      :authenticate=>true, :credentials_file=>@credentials_file, :readline=>true)
    lc.start_blocking
  end

  private
  def initialize_rails_env
    puts "Initializing rails environment..."
    require File.expand_path('config/application')
    Rails.application.require_environment!
    if Gem::Version.new(Rails::VERSION::STRING) >= Gem::Version.new('3.1.0')
      Rails.application.sandbox = false
      Rails.application.load_console
    else
      Rails.application.load_console(false)
    end
    if Gem::Version.new(Rails::VERSION::STRING) >= Gem::Version.new('3.2.0')
      IRB::ExtendCommandBundle.send :include, Rails::ConsoleMethods
    end
  end
end

cred_file = File.expand_path('../.consoleaccess', __FILE__)
puts "The file #{cred_file}"
rails_console = RailsConsole.new(:port => ENV["VCAP_CONSOLE_PORT"], :host => '0.0.0.0',
  :credentials_file=>cred_file)
rails_console.start
