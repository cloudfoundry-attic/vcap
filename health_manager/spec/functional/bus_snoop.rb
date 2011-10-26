# Copyright (c) 2009-2011 VMware, Inc.

require 'nats/client'
require 'uri'
require 'vcap/common'
require 'yaml'

class BusSnoop

  NATS_URI_DEFAULT = 'nats://localhost:4222/'

  def initialize(options = {})
    @uri = options[:uri] || NATS_URI_DEFAULT
  end

  def stop
    NATS.stop
  end

  def start
    NATS.start :uri => @uri do
      NATS.subscribe(">") do |msg, reply, sub|

        if block_given?
          yield msg, reply, sub
        else
          begin
            puts sub
            puts parse_json(msg).to_yaml

          rescue Yajl::ParseError => e

            puts "ERROR: Yajl::ParseError: #{e}\nSubject: '#{sub}'\nMessage follows\n#{msg}"
            NATS.stop
          end

        end
      end
    end
  end


end

def parse_json str
  Yajl::Parser.parse(str)
end

def parse_args(args)
  opts = {}
  opts[:uri] = args.shift unless args.empty?
  opts[:pattern] = args.shift unless args.empty?
  opts
end


#when run on the command line, starts snooping right away using command line args for parameteres
#otherwise can be used as a library
if __FILE__ == $0
  options = parse_args($*)

  hm_pattern = 'dea\.heartbeat|healthmanager\.(status|health)|droplet\.(exited|updated)|cloudcontrollers\.hm\.requests'

  snoop = BusSnoop.new(options)
  re = Regexp.new( options[:pattern] || hm_pattern)

  puts "Starting the BusSnoop at #{@uri} listening on '#{re}'"
  snoop.start do |msg, reply, sub|
    next unless re.match sub
    puts sub
    puts parse_json(msg).to_yaml
  end
end
