#!/usr/bin/ruby
require 'rest-client'

port = '3000'

#test remote gem load
RestClient.put "localhost:#{port}/load/remote/webmock-1.5.0.gem", ''

