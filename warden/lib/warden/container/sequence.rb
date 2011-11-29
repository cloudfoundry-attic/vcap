require "warden/logger"
require "warden/errors"
require "warden/container/spawn"

require "fiber"

module Warden

  module Container

    class Sequence

      def self.execute!
        seq = Sequence.new
        yield(seq)
        seq.execute!
      end

      include Logger

      attr_reader :steps

      def initialize
        @steps = []
      end

      def step(name = nil, &blk)
        name ||= "step no. #{steps.size + 1}"
        steps << Step.new(name, &blk)
      end

      def execute!
        rollback = []
        steps.each { |step|
          rollback << step
          step.execute!
        }

      rescue WardenError
        rollback.reverse.each { |step|
          begin
            debug "#{step.name}: rollback"
            step.rollback!
          rescue => err
            error "#{step.name}: rollback failed (#{err.message})"
          end
        }

        raise
      end

      class Step

        include Logger
        include Spawn

        attr_reader :name

        def initialize(name, &blk)
          @name = name
          yield(self)
        end

        def execute(&blk)
          @execute = blk
        end

        def execute!
          @execute.call if @execute
        end

        def rollback(&blk)
          @rollback = blk
        end

        def rollback!
          @rollback.call if @rollback
        end
      end
    end
  end
end
