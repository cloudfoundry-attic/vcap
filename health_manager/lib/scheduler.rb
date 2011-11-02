module HealthManager2
  class Scheduler
    def initialize( config={} )
      @config = config
      @tasks = []
    end

    def schedule( options = { :immediate => true }, &block)
      raise ArgumentError unless options.length == 1
      raise ArgumentError, 'block required' unless block_given?
      arg = options.first
      sendee = {
        :immediate => [:next_tick],
        :periodic => [:add_periodic_timer],
        :timer => [:add_timer],
      }[arg.first]

      raise ArgumentError,"Unknown scheduling keyword, please use :immediate, :periodic or :timer" unless sendee
      sendee << arg.second unless arg.first == :immediate
      @tasks << [block, sendee]
    end

    def run
      until @tasks.empty?
        block, sendee = @tasks.shift
        EM.send( *sendee, &block )
      end
    end

    def start
      EM.run do
        run
      end
    end

    def stop
      EM.stop
    end
  end
end
