# VCAP Stager Client

Provides client implementations for queuing staging tasks. Currently, the
following clients are provided:

_EmAware_

Intended to be used when dealing with EM directly.

Sample usage:

    client = VCAP::Stager::Client::EmAware.new(nats_connection, queue)

    # Send the request, wait up to 10 seconds for a result
    promise = client.stage(request, 10)

    # Block will be invoked on any reply that is received (regardless of
    # whether or not the Stager succeeded or failed).
    promise.on_response { |r| puts "Received response: #{r}" }

    # Block will be invoked when an error occurs while processing the request.
    # This includes errors deserializing the response and timeouts waiting for
    # a reply.
    promise.on_error { |e| puts "An error occurred: #{e}" }

_FiberAware_

Intended to be used with EM + Fibers. Emulates a blocking api by yielding the
calling fiber until the request completes.

Sample usage:

    Fiber.new do
      client = VCAP::Stager::Client::FiberAware.new(nats_connection, queue)

      begin
        # Send the request, wait for up to 10 seconds to reply. The current
        # fiber is resumed once the request has completed.
        result = client.stage(request, 10)
      rescue => e
        # Exceptions that occur while performing the request are raised in
        # the calling fiber.
        puts "An error, #{e}, occurred"
      end
    end