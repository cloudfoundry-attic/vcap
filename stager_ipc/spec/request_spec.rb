require File.expand_path('../spec_helper', __FILE__)

describe VCAP::Stager::Ipc::Request do
  describe '#encode' do
    it 'should raise VCAP::Stager::Ipc::EncodeError if json encoding fails' do
      Yajl::Encoder.should_receive(:encode).with(any_args()).and_raise("TEST: Oh noes!")
      req = VCAP::Stager::Ipc::Request.new(:foo, 'hi')
      expect do
        req.encode
      end.to raise_error(VCAP::Stager::Ipc::EncodeError)
    end
  end

  describe '#decode' do
    it 'should raise VCAP::Stager::Ipc::DecodeError if decoding fails' do
      expect do
        VCAP::Stager::Ipc::Request.decode("invalid")
      end.to raise_error(VCAP::Stager::Ipc::DecodeError)
    end

    it 'should decode correctly encoded request, and the decoded request should be identical' do
      req = VCAP::Stager::Ipc::Request.new(:test, ['hi', 'there'])
      dec_req = VCAP::Stager::Ipc::Request.decode(req.encode)
      dec_req.class.should == VCAP::Stager::Ipc::Request
      dec_req.method.should == req.method
      dec_req.args.should == req.args
      dec_req.request_id.should == req.request_id
    end
  end
end
