# Copyright (c) 2009-2011 VMware, Inc.

require 'nats/client'
require 'uri'
require 'vcap/common'
require 'yaml'

class BusSnoop

  NATS_URI_DEFAULT = 'nats://localhost:4222/'
  PATTERN_DEFAULT = '>'

  def initialize(options = {})
    @uri = options[:uri] || NATS_URI_DEFAULT
    @pattern = options[:pattern] || PATTERN_DEFAULT
  end

  def stop
    NATS.stop
  end

  def start
    puts "Starting the BusSnoop at #{@uri} listening on '#{@pattern}'"
    NATS.start :uri => @uri do
      NATS.subscribe(@pattern) do |msg, reply, sub|
        if block_given?
          yield msg
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

  def parse_json str
    Yajl::Parser.parse(str)
  end
end


def parse_args(args)
  opts = {}
  opts[:pattern] = args.shift unless args.empty?
  opts[:uri] = args.shift unless args.empty?
  opts
end


#when run on the command line, starts snopping right away using command line args for parameteres
#otherwise can be used as a library
if __FILE__ == $0
  options = parse_args($*)

  snoop = BusSnoop.new(options)
  snoop.start
end
