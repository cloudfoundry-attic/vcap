# Insecure container should be available on all platforms
require "warden/container/insecure"

# Require Linux container only when running on Linux
if RUBY_PLATFORM =~ /linux/i
  require "warden/container/linux"
else
  # Define stub
  class Warden::Container::Linux; end
end
