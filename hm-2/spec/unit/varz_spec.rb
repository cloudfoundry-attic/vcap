require 'spec_helper'

include HealthManager2

describe HealthManager2 do
  describe Varz do

    before :each do
      @v = Varz.new
    end

    def v; @v; end

    it 'should allow declaring counters' do
      v.declare_counter :counter1
      v.get(:counter1).should == 0
    end

    it 'should allow declaring nodes and subcounters' do
      v.declare_node :node
      v.declare_counter :node, :foo
      v.declare_node :node, :node1
      v.declare_counter :node, :node1, :foo
    end

    it 'should disallow double declarations' do
      v.declare_counter :foo
      v.declare_counter :bar
      vv = Varz.new
      vv.declare_counter :foo #ok to declare same counters for different Varz objects
      lambda { v.declare_counter(:foo).should raise_error ArgumentError }
    end

    it 'should disallow undeclared counters' do
      lambda { v.get :counter_bogus }.should raise_error ArgumentError
      lambda { v.inc :counter_bogus }.should raise_error ArgumentError
      v.declare_node :foo
      v.declare_counter :foo, :bar
      lambda { v.reset :foo, :bogus }.should raise_error ArgumentError
    end

    it 'should properly increment and reset counters' do
      v.declare_counter :foo
      v.declare_node :node
      v.declare_counter :node, :bar

      v.get(:foo).should == 0
      v.inc(:foo).should == 1
      v.get(:foo).should == 1

      10.times { v.inc :foo }
      v.get(:foo).should == 11
      v.get(:node, :bar).should == 0
      v.inc(:node, :bar).should == 1
      v.get(:foo).should == 11

      v.reset :foo
      v.get(:foo).should == 0
      v.get(:node, :bar).should == 1
    end

    it 'should allow setting of counters' do
      v.declare_node :node
      v.declare_node :node, 'subnode'
      v.declare_counter :node, 'subnode', 'counter'
      v.set 30, :node, 'subnode', 'counter'
      v.get(:node, 'subnode', 'counter').should == 30

      v.inc :node, 'subnode', 'counter'
      v.get(:node, 'subnode', 'counter').should == 31
    end

    it 'should return valid varz' do
      v.declare_counter :total_apps
      v.declare_node :frameworks
      v.declare_node :frameworks, 'sinatra'
      v.declare_counter :frameworks, 'sinatra', :apps

      v.set 10, :total_apps
      10.times { v.inc :frameworks, 'sinatra', :apps }

      v.get_varz.should == {
        :total_apps => 10,
        :frameworks => { 'sinatra' => {:apps => 10 }}}
    end
  end
end
