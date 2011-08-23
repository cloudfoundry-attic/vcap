#!/usr/bin/ruby
$:.unshift(File.join(File.dirname(__FILE__)))
require 'rest-client'

port = '9292'

#RestClient.get 'localhost:9292/hello'

#test remote gem load
RestClient.put "localhost:#{port}/load/remote/webmock-1.5.0.gem", ''

#test local gem load
#compute hash on test gem
#copy to inbox/#{hash}.gem
#tell loader to load based on hash
#RestClient.put "localhost:#{port}/load/local/#{hash}.gem"
