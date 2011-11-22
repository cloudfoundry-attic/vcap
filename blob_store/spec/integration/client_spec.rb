require File.dirname(__FILE__) + '/../spec_helper'

describe VCAP::BlobStore::Client do

  before(:each) do
    @httpclient = mock("httpclient")
    HTTPClient.stub!(:new).and_return(@httpclient)
  end

  describe "options" do

    it "should set up authentication when present" do
      response = mock("response")
      response.stub!(:status).and_return(200)
      response.stub!(:content).and_return("content_id")

      @httpclient.should_receive(:get).with("http://localhost/resources/foo", {},
                                            {"Authorization"=>"Basic am9objpzbWl0aA=="}).and_return(response)
      @client = VCAP::BlobStore::Client.new({"endpoint" => "http://localhost",
                                                            "user" => "john",
                                                            "password" => "smith"})
      @client.get("foo")
    end

  end

  describe "operations" do

    it "should create an object" do
      pending("create object example") do
        response = mock("response")
        response.stub!(:status).and_return(200)
        response.stub!(:content).and_return("content_id")
        @httpclient.should_receive(:post).with { |*args|
          uri, body, _ = args
          uri.should eql("http://localhost/resources")
          body.should be_kind_of(Hash)
          body[:content].should be_kind_of(File)
          body[:content].read.should eql("some object")
          true
        }.and_return(response)

        @client = VCAP::BlobStore::Client.new({"endpoint" => "http://localhost"})
        @client.create("some object").should eql("content_id")
      end
    end

    it "should raise an exception when there is an error creating an object" do
      pending("create exception example") do
        response = mock("response")
        response.stub!(:status).and_return(500)

        @httpclient.should_receive(:post).with { |*args|
          uri, body, _ = args
          uri.should eql("http://localhost/resources")
          body.should be_kind_of(Hash)
          body[:content].should be_kind_of(File)
          body[:content].read.should eql("some object")
          true
        }.and_return(response)

        @client = VCAP::BlobStore::Client.new({"endpoint" => "http://localhost"})
        lambda {@client.create("some object")}.should raise_error
      end
    end

    it "should fetch an object" do
      pending("get fetch example working") do
        response = mock("response")
        response.stub!(:status).and_return(200)
        @httpclient.should_receive(:get).with("http://localhost/resources/some object", {}, {}).
            and_yield("content_id").
            and_return(response)

        @client = VCAP::BlobStore::Client.new({"endpoint" => "http://localhost"})
        @client.get("some object").should == "content_id"
      end
    end

    it "should raise an exception when there is an error fetching an object" do
      response = mock("response")
      response.stub!(:status).and_return(500)
      response.stub!(:content).and_return("error message")
      @httpclient.should_receive(:get).with("http://localhost/resources/some object", {}, {}).and_return(response)

      @client = VCAP::BlobStore::Client.new({"endpoint" => "http://localhost"})
      lambda {@client.get("some object")}.should raise_error
    end

    it "should delete an object" do
      response = mock("response")
      response.stub!(:status).and_return(204)
      response.stub!(:content).and_return("")
      @httpclient.should_receive(:delete).with("http://localhost/resources/some object", {}).and_return(response)

      @client = VCAP::BlobStore::Client.new({"endpoint" => "http://localhost"})
      @client.delete("some object")
    end

    it "should raise an exception when there is an error deleting an object" do
      response = mock("response")
      response.stub!(:status).and_return(404)
      response.stub!(:content).and_return("")
      @httpclient.should_receive(:delete).with("http://localhost/resources/some object", {}).and_return(response)

      @client = VCAP::BlobStore::Client.new({"endpoint" => "http://localhost"})
      lambda {@client.delete("some object")}.should raise_error
    end

  end

end
