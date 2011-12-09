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
      end

      include Logger

      def initialize
        @steps = []
      end

      def step(name = nil, &blk)
        name ||= "step no. #{@steps.size + 1}"
        step = Step.new(name, &blk)

        # Execute steps as they are defined
        @steps << step
        step.execute!

      rescue WardenError
        @steps.reverse.each { |step|
          begin
            step.rollback!
          rescue WardenError
            # ignore
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
          debug "#{name}: executing"
          @execute.call if @execute
        end

        def rollback(&blk)
          @rollback = blk
        end

        def rollback!
          debug "#{name}: rolling back"
          @rollback.call if @rollback

        rescue WardenError => err
          error "#{name}: rollback failed (#{err.message})"
          raise
        end
      end
    end
  end
end
