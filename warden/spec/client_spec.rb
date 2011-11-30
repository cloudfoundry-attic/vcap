require "spec_helper"
require "warden/client"

describe Warden::Client do

  include_context :warden_server

  let(:container_klass) {
    # These specs shouldn't impact container-related code
    mock("container klass").as_null_object
  }

  let(:client) {
    Warden::Client.new(unix_domain_path)
  }

  it "triggers the connected event" do
    em do
      client.on(:connected) { done }
    end
  end

  it "calls deferred callback for successful commands" do
    em do
      deferrable = client.call("ping")
      deferrable.callback { |reply|
        reply.should == "pong"
        done
      }
      deferrable.errback { |reply|
        fail
      }
    end
  end

  it "calls deferred errback for failed commands" do
    em do
      deferrable = client.call("foo")
      deferrable.callback { |reply|
        fail
      }
      deferrable.errback { |reply|
        reply.message.should match(/unknown command/)
        done
      }
    end
  end
end
