require '../lib/scheduler.rb'

include HealthManager2

describe HealthManager2 do
  describe Scheduler do

    before(:each) do
      @s = Scheduler.new
    end

    it 'should be able to schedule own termination' do
      @s.schedule :timer => 1 do
        @s.stop
      end
      start_at = Time.now.to_i
      @s.start
      stop_at = Time.now.to_i
      stop_at.should > start_at #at least a second should have elapsed
    end

    it 'should be able to schedule immediate task' do
      done = false
      @s.schedule do
        done = true
      end
      @s.schedule do #also scheduled immediately, but at the next tick
        @s.stop
      end
      @s.start
      done.should be_true
    end

    it 'should be able to schedule periodic task' do
      count = 0

      @s.schedule :timer => 1 do
        @s.stop
      end

      @s.schedule :periodic => 0.3 do
        count += 1
      end

      @s.start
      count.should == 3
    end

    it 'should be able to schedule several various tasks' do

      #this shows running the scheduler within explicit EM.run

      EM.run do
        @counter = Hash.new(0)

        #schedule tasks, setup expectations, run scheduler

        @s.schedule( :immediate => true) do
          @counter[:immediate] += 1
        end

        @s.schedule do
          @counter[:default] += 1
        end

        @s.schedule( :periodic => 1.5) do
          @counter[:periodic] += 1
        end

        @s.schedule( :timer => 3) do
          @counter[:timer] += 1
        end

        #set up expectations for two points in time: 0.5 and 4 seconds away

        EM.add_timer(0.5) do
          @counter[:immediate].should == 1
          @counter[:default].should == 1
          @counter[:periodic].should == 0
          @counter[:timer].should == 0
        end

        EM.add_timer(4) do
          @counter[:immediate].should == 1
          @counter[:default].should == 1
          @counter[:periodic].should == 2
          @counter[:timer].should == 1
          EM.stop
        end
        @s.run
      end
    end
  end
end
