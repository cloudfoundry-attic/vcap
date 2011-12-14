#!/usr/bin/env ruby

# Run setup for every subdirectory
path = File.expand_path("..", __FILE__)
Dir[File.join(path, "*/setup.rb")].sort.each { |e|
  system(e) || fail
}
