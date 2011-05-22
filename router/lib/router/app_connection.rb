# Copyright (c) 2009-2011 VMware, Inc.
module AppConnection

  attr_reader :oustanding_requests

  def initialize(client, request, droplet)
    Router.log.debug "Creating AppConnection"
    @client, @request, @droplet = client, request, droplet
    @start_time = Time.now
    @connected = false
    @outstanding_requests = 1
    Router.outstanding_request_count += 1
  end

  def post_init
    VCAP::Component.varz[:app_connections] = Router.app_connection_count += 1
    Router.log.debug "Completed AppConnection"
    Router.log.debug Router.connection_stats
    Router.log.debug "------------"
  end

  def connection_completed
    @connected = true
    #proxy_incoming_to(@client) if @client
    send_data(@request) if @client && @request
  end

  # queue data until connection completed.
  def deliver_data(data)
    return send_data(data) if @connected
    @request << data
  end

  # We have the HTTP Headers complete from the client
  def on_headers_complete(headers)
    check_sticky_session = STICKY_SESSIONS =~ headers[SET_COOKIE_HEADER]
    sent_session_cookie = false # Only send one in case of multiple hits

    header_lines = @headers.split("\r\n")
    header_lines.each do |line|
      @client.send_data(line)
      @client.send_data(CR_LF)
      if (check_sticky_session && !sent_session_cookie && STICKY_SESSIONS =~ line)
        sid = Router.generate_session_cookie(@droplet)
        scl = line.sub(/\S+\s*=\s*\w+/, "#{VCAP_SESSION_ID}=#{sid}")
        sent_session_cookie = true
        @client.send_data(scl)
        @client.send_data(CR_LF)
      end
    end
    # Trace if properly requested
    if @client.trace
      router_trace = "#{VCAP_ROUTER_HEADER}:#{Router.inet}#{CR_LF}"
      be_trace = "#{VCAP_BACKEND_HEADER}:#{@droplet[:host]}:#{@droplet[:port]}#{CR_LF}"
      @client.send_data(router_trace)
      @client.send_data(be_trace)
    end
    # Ending CR_LF
    @client.send_data(CR_LF)
  end

  def process_response_body_chunk(data)
    return unless data

    # Let parser process as well to properly determine end of message.
    # TODO: Once EM 1.0, add in optional bytsize proxy if Content-Length is present.
    psize = @parser << data
    if (psize == data.bytesize)
      @client.send_data(data)
    else
      Router.log.info "Pipelined response detected!"
      # We have a pipelined response, we need to hand over the new headers and only send the proper
      # body segments to the backend
      body = data.slice!(0, psize)
      @client.send_data(body)
      receive_data(data)
    end
  end

  def record_stats
    return unless @parser

    latency = ((Time.now - @start_time) * 1000).to_i
    response_code = @parser.status_code
    response_code_metric = :responses_xxx
    if (200..299).include?(response_code)
      response_code_metric = :responses_2xx
    elsif (300..399).include?(response_code)
      response_code_metric = :responses_3xx
    elsif (400..499).include?(response_code)
      response_code_metric = :responses_4xx
    elsif (500..599).include?(response_code)
      response_code_metric = :responses_5xx
    end

    VCAP::Component.varz[response_code_metric] += 1
    VCAP::Component.varz[:latency] << latency

    if @droplet[:tags]
      @droplet[:tags].each do |key, value|
        tag_metrics = VCAP::Component.varz[:tags][key][value]
        tag_metrics[response_code_metric] += 1
        tag_metrics[:latency] << latency
      end
    end
  end

  def on_message_complete
    record_stats
    @parser = nil
    @outstanding_requests -= 1
    Router.outstanding_request_count -= 1
    :stop
  end

  def cant_be_recycled?
    error? || @parser != nil || @connected == false || @outstanding_requests > 0
  end

  def recycle
    stop_proxying
    @client = @request = @headers = nil
  end

  def receive_data(data)
    # Parser is created after headers have been received and processed.
    # If it exists we are continuing the processing of body fragments.
    # Allow the parser to process to signal proper end of message, e.g. chunked, etc
    return process_response_body_chunk(data) if @parser

    # We are awaiting headers here.
    # We buffer them if needed to determine the header/body boundary correctly.
    @buf = @buf ? @buf << data : data
    if hindex = @buf.index(HTTP_HEADERS_END) # all http headers received, figure out where to route to..
      @parser = Http::Parser.new(self)

      # split headers and rest of body out here.
      @headers = @buf.slice!(0...hindex+HTTP_HEADERS_END_SIZE)

      # Process headers
      @parser << @headers

      # Process left over body fragment if any
      process_response_body_chunk(@buf) if @parser
      @buf = @headers = nil
    end

  rescue Http::Parser::Error => e
    Router.log.debug "HTTP Parser error on response: #{e}"
    close_connection
  end

  def rebind(client, request)
    @start_time = Time.now
    @client = client
    reuse(request)
  end

  def reuse(new_request)
    @request = new_request
    @outstanding_requests += 1
    Router.outstanding_request_count += 1
    deliver_data(@request)
  end

  def proxy_target_unbound
    Router.log.debug "Proxy connection dropped"
    #close_connection_after_writing
  end

  def unbind
    Router.outstanding_request_count -= @outstanding_requests
    unless @connected
      Router.log.info "Could not connect to backend for url:#{@droplet[:url]} @ #{@droplet[:host]}:#{@droplet[:port]}"
      if @client
        @client.send_data(Router.notfound_redirect || ERROR_404_RESPONSE)
        @client.close_connection_after_writing
      end
      # TODO(dlc) fix - We will unregister bad backends here, should retry the request if possible.
      Router.unregister_droplet(@droplet[:url], @droplet[:host], @droplet[:port])
    end

    VCAP::Component.varz[:app_connections] = Router.app_connection_count -= 1
    Router.log.debug 'Unbinding AppConnection'
    Router.log.debug Router.connection_stats
    Router.log.debug "------------"

    # Remove ourselves from the connection pool
    @droplet[:connections].delete(self)

    @client.close_connection_after_writing if @client
  end

  def terminate
    stop_proxying
    close_connection
    on_message_complete if @outstanding_requests > 0
  end

end
