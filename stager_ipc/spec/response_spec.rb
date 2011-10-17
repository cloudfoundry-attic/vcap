require File.expand_path('../spec_helper', __FILE__)

describe VCAP::Stager::Ipc::Response do
  describe '#encode' do
    it 'should raise VCAP::Stager::Ipc::EncodeError if json encoding fails' do
      Yajl::Encoder.should_receive(:encode).with(any_args()).and_raise("TEST: Oh noes!")
      resp = VCAP::Stager::Ipc::Response.new(1, 'inbox')
      expect do
        resp.encode
      end.to raise_error(VCAP::Stager::Ipc::EncodeError)
    end
  end

  describe '#decode' do
    it 'should raise VCAP::Stager::Ipc::DecodeError if decoding fails' do
      expect do
        VCAP::Stager::Ipc::Response.decode("invalid")
      end.to raise_error(VCAP::Stager::Ipc::DecodeError)
    end

    it 'should decode correctly encoded response, and the decoded response should be identical' do
      resp = VCAP::Stager::Ipc::Response.new(1, 'inbox')
      dec_resp = VCAP::Stager::Ipc::Response.decode(resp.encode)
      dec_resp.class.should == VCAP::Stager::Ipc::Response
      dec_resp.request_id.should == resp.request_id
      dec_resp.result.should == resp.result
    end
  end
end
