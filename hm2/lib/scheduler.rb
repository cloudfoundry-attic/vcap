module HealthManager2
  class Scheduler
    def initialize( config={} )
      @config = config
      @schedule = []
      @last_receipt = 0
      @receipt_to_timer = {}
      @running_tasks = {}
    end

    def schedule( options, &block)
      raise ArgumentError unless options.length == 1
      raise ArgumentError, 'block required' unless block_given?
      arg = options.first
      sendee = {
        :periodic => [:add_periodic_timer],
        :timer => [:add_timer],
      }[arg.first]

      raise ArgumentError,"Unknown scheduling keyword, please use :immediate, :periodic or :timer" unless sendee
      sendee << arg[1]
      receipt = get_receipt
      @schedule << [block, sendee, receipt]
      receipt
    end

    def after_interval(interval_name, &block)
      after(get_interval(interval_name), &block)
    end

    def at_interval(interval_name, &block)
      every(get_interval(interval_name), &block)
    end

    def get_interval(name)
      get_interval_from_config_or_constant(name, @config)
    end

    def every(interval, &block)
      schedule( :periodic => interval, &block)
    end

    def after(interval, &block)
      schedule(:timer => interval, &block)
    end

    def immediately(&block)
      EM.next_tick(&block)
    end

    def run
      until @schedule.empty?
        block, sendee, receipt = @schedule.shift
        @receipt_to_timer[receipt] = EM.send(*sendee, &block)
      end
    end

    def cancel(receipt)

      if @receipt_to_timer.has_key?(receipt)
        EM.cancel_timer(@receipt_to_timer.delete(receipt))
      else
        @schedule.reject! { |_,_,r|  (r == receipt) }
      end
    end

    def quantize_task(task, &block)
      if yield
        EM.next_tick { quantize_task( task, &block) }
      else
        mark_task_stopped(task)
      end
    end

    def start_task(task, &block)
      return if task_running?(task)
      mark_task_started(task)
      quantize_task(task, &block)
    end

    def mark_task_started(task)
      @running_tasks[task] = :started
    end

    def mark_task_stopped(task)
      raise ArgumentError, "task #{task} not started" unless @running_tasks.delete(task)
    end
    def task_running?(task)
      @running_tasks[task] == :started
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

  private
  def get_receipt
    @last_receipt += 1
  end
end
