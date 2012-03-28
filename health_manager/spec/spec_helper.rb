# Copyright (c) 2009-2011 VMware, Inc.
$:.unshift File.join(File.dirname(__FILE__), '..')
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'rspec'
require 'health_manager'
require 'fiber'

module Spec
  module Mocks
    module ArgumentMatchers

      class JsonStringMatcher
        def initialize(expected)
          @expected = expected
        end

        def ==(actual)
          JSON.parse(actual).eql?(@expected)
        end

        def description
          @expected.to_json
        end
      end

      def json_string(expected)
        JsonStringMatcher.new(expected)
      end

    end
  end
end

module Kernel
  def silence_warnings
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    result = yield
    $VERBOSE = original_verbosity
    return result
  end
end

