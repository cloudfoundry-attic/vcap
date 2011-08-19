require "logger"

# Build a Logger::Formatter subclass.
class DebugFormatter < Logger::Formatter
  # Provide a call() method that returns the formatted message.
  def call(severity, time, program_name, message)
      file,line,method = caller[3].split(':')
      file = File.basename(file)
      "#{severity}:#{file}:#{line}:#{method}>> #{String(message)}\n"
  end
end

def test_format
  log           = Logger.new(STDOUT)
  log.level     = Logger::DEBUG
  log.formatter = DebugFormatter.new  # Install custom formatter!
  log.debug("We're not in the verbose debug mode.")
end

if __FILE__ == $0
  test_method
end
