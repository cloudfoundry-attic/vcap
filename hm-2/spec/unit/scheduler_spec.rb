require 'spec_helper'

include HealthManager2

describe HealthManager2 do
  describe Scheduler do

    before(:each) do
      @s = Scheduler.new
    end

    describe '#get_interval' do
      it 'should return configured interval values' do
        s1 = Scheduler.new( :intervals => {:dea_timeout_interval =>7 } )
        s2 = Scheduler.new( 'intervals' => {'dea_timeout_interval' =>6 } )

        s1.get_interval(:dea_timeout_interval).should == 7
        s1.get_interval('dea_timeout_interval').should == 7
        s2.get_interval(:dea_timeout_interval).should == 6
        s2.get_interval('dea_timeout_interval').should == 6
      end

      it 'should return default interval values' do
        s = Scheduler.new
        s.get_interval(:dea_timeout_interval).should == DEA_TIMEOUT_INTERVAL
        s.get_interval('dea_timeout_interval').should == DEA_TIMEOUT_INTERVAL
      end

      it 'should raise ArgumentError for invalid intervals' do
        lambda { @s.get_interval(:bogus) }.should raise_error(ArgumentError, /undefined parameter/)
      end
    end

    it 'should be able to schedule own termination' do
      @s.schedule :timer => 1 do
        @s.stop
      end
      start_at = now
      @s.start
      stop_at = now
      stop_at.should > start_at #at least a second should have elapsed
    end

    it 'should be able to execute immediately' do
      done = false
      @s.immediately do
        done = true
      end
      @s.immediately do
        @s.stop
      end
      @s.start
      done.should be_true
    end

    it 'should be able to schedule periodic' do
      count = 0
      @s.schedule :timer => 1.1 do
        @s.stop
      end

      @s.schedule :periodic => 0.3 do
        count += 1
      end

      @s.start
      count.should == 3
    end

    it 'should be able to schedule multiple blocks' do
      #this shows running the scheduler within explicit EM.run
      EM.run do
        @counter = Hash.new(0)
        @s.immediately do
          @counter[:immediate] += 1
        end
        @s.every 0.3 do
          @counter[:periodic] += 1
        end
        @s.every 0.7 do
          @counter[:timer] += 1
        end
        #set up expectations for two points in time:
        EM.add_timer(0.5) do
          @counter[:immediate].should == 1
          @counter[:periodic].should == 1
          @counter[:timer].should == 0
        end
        EM.add_timer(1.1) do
          @counter[:immediate].should == 1
          @counter[:periodic].should == 3
          @counter[:timer].should == 1
          EM.stop
        end
        @s.run
      end
    end

    it 'should allow cancelling scheduled blocks' do
      flag = false
      cancelled_flag = false

      cancelled_timer1 = @s.schedule(:timer => 0.1) do
        cancelled_flag = true
      end

      cancelled_timer2 = @s.schedule(:timer => 0.3) do
        cancelled_flag = true
      end

      @s.after 0.2 do
        flag = true
        @s.cancel(cancelled_timer2)
      end

      @s.after 1 do
        @s.stop
      end

      @s.cancel(cancelled_timer1)

      @s.start

      cancelled_flag.should be_false
      flag.should be_true
    end

    it 'should be able to start/stop/quantize tasks' do

      iters = 0
      @s.after 0.1 do
        @s.start_task(:boo) do
          iters += 1
          @s.task_running?(:boo).should be_true
          iters < 5 #continuation condition
        end
      end

      @s.after 0.2 do
        @s.stop
      end

      @s.task_running?(:boo).should be_false
      @s.start
      iters.should == 5
      @s.task_running?(:boo).should be_false
    end
  end
end
