#!/usr/bin/env rackup

use Rack::ContentLength

app = Rack::Directory.new Dir.pwd
run app
