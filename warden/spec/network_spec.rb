require "spec_helper"

describe Warden::Network do
  describe Warden::Network::Netmask do
    def instance(*octets)
      Warden::Network::Netmask.new(*octets)
    end

    it "should raise on invalid masks" do
      test = lambda { |octets|
        lambda {
          instance(*octets)
        }.should raise_error
      }

      [
        [255, 255, 255, 253],
        [255, 255, 255, 251],
        [255, 255, 255, 250],
        [255, 255, 255, 249],
        [255, 255, 255, 247],
        [255, 255, 254, 1],
        [255, 255, 253, 0],
      ].each(&test)
    end

    it "should accept valid masks" do
      test = lambda { |octets|
        lambda {
          instance(*octets)
        }.should_not raise_error
      }

      [
        [255, 255, 255, 255],
        [255, 255, 255, 254],
        [255, 255, 255, 252],
        [255, 255, 255, 248],
        [255, 255, 255, 240],
        [255, 255, 254, 0],
        [255, 255, 252, 0],
      ].each(&test)
    end

    it "should know its size" do
      instance(255, 255, 255, 255).size.should == 1
      instance(255, 255, 255, 254).size.should == 2
      instance(255, 255, 255, 252).size.should == 4
      instance(255, 255, 254, 0).size.should == 512
      instance(255, 255, 252, 0).size.should == 1024
    end
  end

  describe Warden::Network::Address do
    it "should know its network given a mask" do
      mask = Warden::Network::Netmask.new(255, 255, 255, 0)
      address = Warden::Network::Address.new(10, 0, 128, 54)
      address.network(mask).should eql Warden::Network::Address.new(10, 0, 128, 0)
    end
  end
end
