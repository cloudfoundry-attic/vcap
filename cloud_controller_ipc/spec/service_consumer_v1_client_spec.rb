require File.expand_path('../spec_helper', __FILE__)

describe VCAP::CloudController::Ipc::ServiceConsumerV1Client do
  before :all do
    @host   = '127.0.0.1'
    @port   = 80
    @client = VCAP::CloudController::Ipc::ServiceConsumerV1Client.new(@host, @port)
  end

  describe '#perform_request' do
    before :each do
      @uri = build_uri('/test')
    end

    it 'should pass along the staging_task_id as a header field if supplied' do
      client = VCAP::CloudController::Ipc::ServiceConsumerV1Client.new(@host, @port, :staging_task_id => '5')
      stub_request(:post, @uri).with(:headers => {'X-Vcap-Staging-Task-Id' => '5'})
      client.send(:perform_request, Net::HTTP::Post, '/test')
    end

    it 'should decode the response body on success' do
      result = {'foo' => 'bar'}
      enc_result = Yajl::Encoder.encode(result)
      stub_request(:post, @uri).to_return(:status => 200, :body => enc_result)
      resp = @client.send(:perform_request, Net::HTTP::Post, '/test')
      resp[:result].should == result
    end

    it 'should return the response as an error on non-200 replies' do
      stub_request(:post, @uri).to_return(:status => 400)
      resp = @client.send(:perform_request, Net::HTTP::Post, '/test')
      resp[:error].should_not be_nil
      resp[:error].code.should == '400'
    end
  end

  describe '#provision_service' do
    it 'should issue a post request to /services/v1/configurations with the correct request body' do
      uri = build_uri('/services/v1/configurations')
      serv_req = {
        :label => 'fooservice-1.1',
        :name  => 'test',
        :plan  => 'free',
        :plan_option => nil,
      }
      stub_request(:post, uri).with(:body => serv_req)
      @client.provision_service(serv_req[:label], serv_req[:name], serv_req[:plan])
    end
  end

  describe '#bind_service' do
    it 'should issue a post request to /services/v1/bindings with the correct request body' do
      uri = build_uri('/services/v1/bindings')
      serv_req = {
        :service_id      => 'test',
        :app_id          => 5,
        :binding_options => {:foo => 'bar'},
      }
      stub_request(:post, uri).with(:body => serv_req)
      @client.bind_service(serv_req[:service_id], serv_req[:app_id], serv_req[:binding_options])
    end
  end

  describe '#unprovision_service' do
    it 'should issue a delete request to /services/v1/configurations/:name' do
      service_name = "test_service"
      uri = build_uri("/services/v1/configurations/#{service_name}")
      stub_request(:delete, uri)
      @client.unprovision_service(service_name)
    end
  end

  def build_uri(path, query=nil)
    URI::HTTP.build(
      :host => @host,
      :port => @port,
      :path => path,
      :query => query).to_s
  end
end
