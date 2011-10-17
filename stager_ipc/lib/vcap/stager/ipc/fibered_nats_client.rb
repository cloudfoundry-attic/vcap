require 'eventmachine'
require 'fiber'

require 'vcap/common'
require 'vcap/logging'

require 'vcap/stager/ipc/constants'
require 'vcap/stager/ipc/errors'
require 'vcap/stager/ipc/request'
require 'vcap/stager/ipc/response'

module VCAP
  module Stager
    module Ipc
    end
  end
end

class VCAP::Stager::Ipc::FiberedNatsClient
  def initialize(nats, queue=VCAP::Stager::Ipc::REQUEST_QUEUE)
    @nats   = nats
    @queue  = queue
    @logger = VCAP::Logging.logger('vcap.stager.client')
  end

  # Sends a request to stage an application.
  #
  # @param app_id        Integer  Application id
  # @param props         Hash     Application properties:
  #                                 :runtime     => Application runtime name
  #                                 :framework   => Application framework name
  #                                 :environment => Applications environment variables.
  #                                                 Hash of NAME => VALUE
  #                                 :services    => Services bound to app
  #                                 :resources   => Resource limits
  # @param download_uri  String   Where the stager should fetch the app from
  # @param upload_uri    String   Where the stager should upload the droplet to
  # @param timeout       Integer  How long to wait for a reply
  def add_task(app_id, props, download_uri, upload_uri, timeout=120)
    args = {
      :app_id => app_id,
      :app_properties => props,
      :download_uri   => download_uri,
      :upload_uri     => upload_uri,
    }
    req = VCAP::Stager::Ipc::Request.new(:add_task, args)
    rep = send_request(req, @queue, timeout)
    rep.result
  end

  private

  # @param  req      VCAP::Stager::Ipc::Request
  # @param  subject  String                      NATS subject to publish to
  # @param  timeout  Float
  #
  # @return VCAP::Stager::Ipc::Response
  def send_request(req, subject, timeout)
    f = Fiber.current

    # Wait for reply from the stager
    exp_timer = nil
    sid = @nats.subscribe(req.inbox) do |msg|
      @logger.debug("Received reply from stager on '#{req.inbox}' : '#{msg}'")
      @nats.unsubscribe(sid)
      EM.cancel_timer(exp_timer)
      f.resume(msg)
    end

    # Setup timer to expire our request if we don't get a reply from a stager in time
    exp_timer = EM.add_timer(timeout) do
      err = "Request #{req.request_id} timed out after #{timeout} secs"
      @logger.warn(err)
      @nats.unsubscribe(sid)
      f.resume(VCAP::Stager::Ipc::RequestTimeoutError.new(err))
    end

    enc_req = req.encode
    @logger.debug("Sending request on #{subject}: '#{enc_req}'")
    @nats.publish(subject, enc_req)

    result = Fiber.yield
    if result.kind_of?(VCAP::Stager::Ipc::IpcError)
      raise result
    else
      VCAP::Stager::Ipc::Response.decode(result)
    end
  end
end
