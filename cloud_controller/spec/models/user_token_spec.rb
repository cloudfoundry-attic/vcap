require 'spec_helper'

describe UserToken do
  describe ".decode" do
    before do
      @token = UserToken.new('decode@example.com', Time.now.to_i)
    end

    it "produces a valid token from valid input" do
      token = UserToken.decode(@token.encode)
      token.should be_valid
    end

    it "produces a UserToken object with the same hash as before" do
      token = UserToken.decode(@token.encode)
      token.should == @token
      h = {}
      h[token] = 0
      h[@token] = 1
      h.should have(1).keys
    end

    it "produces an invalid token from well-structured false data" do
      bad = ['root@example.com', Time.now.to_i + 10_000, nil]
      encoded = Marshal.dump(bad).unpack('H*').first
      token = UserToken.decode(encoded)
      token.should_not be_valid
    end

    it "raises an error when the input is not well-formed" do
      lambda do
        UserToken.decode(".....")
      end.should raise_error(ArgumentError)
    end
  end

  describe ".new" do
    it "takes a user name and an expiration timestamp" do
      token = UserToken.new(e = 'spec@example.com', t = Time.now.to_i + 100)
      token.user_name.should == e
      token.valid_until.should == t
    end
  end

  it "is invalid once the expiration time has been reached" do
    token = UserToken.new('invalid@example.com', Time.now.to_i - 100)
    token.should_not be_valid
  end

  describe "#to_json" do
    it "returns the encoded token" do
      token = UserToken.create('json@example.com')
      token.to_json.should == {'token' => token.encode}.to_json
    end
  end

  describe ".hmac" do
    it "accepts a splat of objects that will be fed to HMAC" do
      hmac = UserToken.hmac(1,'2',false,Object.new)
      hmac.should be_kind_of(String)
    end
  end
end

