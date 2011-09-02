$:.unshift(File.join(File.dirname(__FILE__), '..'))
require 'spec_helper'
require 'client'
require 'log_exception'
require 'logger'

class RemoteLoadTester
  attr_accessor :gem_list
  def initialize
    @logger = Logger.new(STDOUT)
    @client = VCAP::PackageCache::Client.new
  end

  def load_gem_list(path)
    @gem_list = []
    gems_file = File.open(path)
    gems_file.each { |line|
      name, rest = line.split(' ')
      version = rest[/[0-9.]+/]
      gem_name = "#{name}-#{version}.gem"
      @gem_list << gem_name
    }
  end

  def print_result(t)
    puts "thread for gem #{t['gem_name']} finished
          in #{t['finish_time'] - t['start_time']} at time #{t['finish_time']}"
  end

  def run_remote_test
    start_time = Time.now
    threads = []
    @gem_list.each { |gem_name|
       threads << Thread.new {
        Thread.current['gem_name'] = gem_name
        Thread.current['start_time'] = Time.now
        puts "adding #{gem_name}"
        begin
        @client.add_remote(gem_name)
        rescue => e
          log_exception(e)
        end

        Thread.current['finish_time'] = Time.now
       }
    }
    threads.each { |t| t.join; print_result(t)}
    puts "Loaded #{@gem_list.size} packages in #{Time.now - start_time} seconds."
  end
end

rt = RemoteLoadTester.new
rt.load_gem_list("gem_list.txt")
rt.run_remote_test

