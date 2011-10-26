require 'spec_helper'

describe VCAP::PriorityQueue do
  before :each do
    @q.should be_nil
    @q = VCAP::PriorityQueue.new
  end

  describe '.new' do
    it 'should be able to create an empty Q' do
      @q.should_not be_nil
    end
  end

  describe '.insert' do
    it 'should respond to insert method with 1 or 2 arguments' do
      @q.insert "boo"
      @q.insert "boo", 1
    end
    it 'should not allow negative priorities' do
      lambda {@q.insert("boo", -1)}.should raise_error ArgumentError
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
      until @q.empty? do
        val = @q.remove
        val.should be < prev
        prev = val
        n-=1
      end
      n.should == 1
    end
  end
end
