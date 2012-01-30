require 'spec_helper'

describe VCAP::PriorityQueueFIFO do
  before :each do
    @q.should be_nil
    @q = VCAP::PriorityQueueFIFO.new
  end

  describe '.new' do
    it 'should be able to create an empty Q' do
      @q.should_not be_nil
    end
  end

  describe '.insert' do
    it 'should respond to insert method with 1 or 2 arguments' do
      @q.insert "boo"
      @q.insert "hoo", 1
    end
    it 'should not allow negative priorities' do
      lambda {@q.insert("bar", -1)}.should raise_error ArgumentError
    end
  end

  describe 'priority specified' do
    it 'should respect specified priorities when returning items' do
      @q.insert "low", 1
      @q.insert "high", 10
      @q.insert "lowest"  #default priority is zero
      @q.insert "highest", 20

      @q.remove.should == "highest"
      @q.remove.should == "high"
      @q.remove.should == "low"
      @q.remove.should == "lowest"
    end
  end

  describe 'high volume' do
    it 'should be able to accept a bunch of random values and return them in non-increasing order' do
      n  = 100_000
      n.times { val = rand ; @q.insert val,val }
      prev = @q.remove

      expect do
        until @q.empty? do
          val = @q.remove
          val.should be < prev
          prev = val
          n-=1
        end
      end.to take_less_than(5).seconds

      n.should == 1
    end
  end

  describe 'high volume FIFO' do
    it 'should have decent FIFO perfomance for same-priority values' do

      n = 100_000
      n.times { |i| @q.insert i }

      prev = @q.remove
      expect do
        until @q.empty? do
          val = @q.remove
          val.should == prev + 1
          prev = val
        end
      end.to take_less_than(1).seconds

        prev.should == n - 1
    end
  end
end

describe VCAP::PrioritySet do
  before :each do
    @qs.should be_nil
    @qs = VCAP::PrioritySet.new
  end

  describe '.new' do
    it 'should be able to new a PrioritySet' do
      @qs.should_not be_nil
    end
  end

  describe 'proper handling of duplicates' do

    it 'should only queue the same object once' do
      @qs.insert "high", 10
      @qs.insert "low", 5
      @qs.insert "low", 6

      @qs.size.should == 2

      @qs.insert "low", 7
      @qs.insert "high", 1 #an updateable priority queue would respect this, but this one won't

      @qs.remove.should == "high"
      @qs.remove.should == "low"
      @qs.empty?.should be_true
    end

    it 'should be able to re-insert an element once it is removed' do

      @qs.insert "item"
      @qs.insert "item"

      @qs.remove.should == "item"
      @qs.empty?.should be_true

      @qs.insert "item"
      @qs.empty?.should be_false

      @qs.remove.should == "item"
    end
  end

  describe 'using key other than element for duplicate elimination' do
    it 'should prevent duplication using supplied key' do
      @qs.insert "low"
      @qs.insert "medium", 5
      @qs.insert "rare", 10, "rare_id"

      @qs.size.should == 3

      @qs.insert "another_rare", 10, "rare_id" #different object, but same key, should not be added
      @qs.size.should == 3

      @qs.insert "another_rare", 15 #no key supplied, since the object is different it should be added
      @qs.size.should == 4

      @qs.remove.should == "another_rare"
      @qs.remove.should == "rare"
      @qs.remove.should == "medium"
      @qs.remove.should == "low"

      @qs.empty?.should be_true

      #should be able to reinsert any item provided the identity is different
      @qs.insert "low"
      @qs.insert "low", 1, "other_id"
      @qs.insert "medium", 3
      @qs.insert "rare", 5, "rare_id"
      @qs.insert "another_rare", 10

      @qs.size.should == 5
    end
  end

  describe 'equal priorities' do
    describe 'FIFO behavior' do
      it 'should FIFO for simplest case' do
        @qs.insert 'first', 1
        @qs.insert 'second', 1
        @qs.insert 'third', 1

        @qs.remove.should == 'first'
        @qs.remove.should == 'second'
        @qs.remove.should == 'third'
      end

      it 'should FIFO for lower and higher priority items interpersed' do

        50.times {|i|
          val, pri = 0,0
          if rand > 0.2
            val, pri = 1000 - i , 2000000000
          else
            val, pri = 100 - i, 100 - i
          end
          @qs.insert(val, pri)
        }
        prev = @qs.remove
        until @qs.empty?
          v = @qs.remove
          v.should < prev
          prev = v
        end
      end

      it 'should retain FIFO ordering when higher priority items are interspersed' do
        @qs.insert 1
        @qs.insert 2
        @qs.insert 'high', 2
        @qs.insert 3
        @qs.insert 4
        @qs.remove.should == 'high'
        @qs.insert 5
        @qs.insert 6
        @qs.remove.should == 1
        @qs.remove.should == 2
        @qs.remove.should == 3
        @qs.remove.should == 4
        @qs.remove.should == 5
        @qs.remove.should == 6

      end
    end
  end
end
