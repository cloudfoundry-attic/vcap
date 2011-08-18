$:.unshift(File.join(File.dirname(__FILE__)))
require 'loader'
ld = Loader.new
ld.load_remote_gem('webmock-1.5.0.gem')
