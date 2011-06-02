require "spec_helper"

describe VCAP::RollingMetric do

  it "should not track anything initially" do
    metric = VCAP::RollingMetric.new(60, 4)
    metric.value.should == {:value => 0, :samples => 0}
  end

  it "should track basic samples" do
    metric = VCAP::RollingMetric.new(60, 4)
    Time.stub!(:now).and_return(0, 15, 30, 45, 45)
    metric << 10
    metric << 20
    metric << 30
    metric << 40
    metric.value.should == {:value => 100, :samples => 4}
  end

  it "should aggregate per bucket" do
    metric = VCAP::RollingMetric.new(60, 4)
    Time.stub!(:now).and_return(0, 5, 10, 15, 15)
    metric << 10
    metric << 20
    metric << 30
    metric << 40
    metric.value.should == {:value => 100, :samples => 4}
  end

  it "should overwrite old samples" do
    metric = VCAP::RollingMetric.new(60, 4)
    Time.stub!(:now).and_return(0, 60, 60)
    metric << 10
    metric << 30
    metric.value.should == {:value => 30, :samples => 1}
  end

  it "should ignore old samples" do
    metric = VCAP::RollingMetric.new(60, 4)
    Time.stub!(:now).and_return(0, 15, 60)
    metric << 10
    metric << 30
    metric.value.should == {:value => 0, :samples => 0}
  end

end
