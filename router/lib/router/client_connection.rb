# Copyright (c) 2009-2011 VMware, Inc.
module ClientConnection

  HTTP_11 ='11'.freeze

  attr_reader :close_connection_after_request, :trace

  def initialize(is_unix_socket)
    Router.log.debug "Created Client Connection"
    @droplet, @bound_app_conn = nil, nil, nil
    # Default to be on the safe side
    @close_connection_after_request = true
    @is_unix_socket = is_unix_socket
  end

  def post_init
    VCAP::Component.varz[:client_connections] = Router.client_connection_count += 1
    Router.log.debug Router.connection_stats
    Router.log.debug "------------"
    self.comm_inactivity_timeout = 60.0
  end

  def recycle_app_conn
    return if (!@droplet || !@bound_app_conn) # Could we leak @bound_app_conn here?

    # Don't recycle if we are not supposed to..
    if @close_connection_after_request
      Router.log.debug "NOT placing bound AppConnection back into free list because a close was requested.."
      @bound_app_conn.close_connection_after_writing
      return
    end

    # Place any bound connections back into the droplets connection pool.
    # This happens on client connection reuse, HTTP 1.1.
    # Check for errors, overcommits, etc..

    if (@bound_app_conn.cant_be_recycled?)
      Router.log.debug "NOT placing AppConnection back into free list, can't be recycled"
      @bound_app_conn.close_connection_after_writing
      return
    end

    if @droplet[:connections].index(@bound_app_conn)
      Router.log.debug "NOT placing AppConnection back into free list, already exists in free list.."
      return
    end

    if @droplet[:connections].size >= MAX_POOL
      Router.log.debug "NOT placing AppConnection back into free list, MAX_POOL connections already exist.."
      @bound_app_conn.close_connection_after_writing
      return
    end

    Router.log.debug "Placing bound AppConnection back into free list.."
    @bound_app_conn.recycle
    @droplet[:connections].push(@bound_app_conn)
    @bound_app_conn = nil
  end

  def terminate_app_conn
    return unless @bound_app_conn
    Router.log.debug "Terminating AppConnection"
    @bound_app_conn.terminate
    @bound_app_conn = nil
  end

  def process_request_body_chunk(data)
    return unless data
    if (@droplet && @bound_app_conn && !@bound_app_conn.error?)

      # Let parser process as well to properly determine end of message.
      psize = @parser << data

      if (psize != data.bytesize)
        Router.log.info "Pipelined request detected!"
        # We have a pipelined request, we need to hand over the new headers and only send the proper
        # body segments to the backend
        body = data.slice!(0, psize)
        @bound_app_conn.deliver_data(body)
        receive_data(data)
      else
        @bound_app_conn.deliver_data(data)
      end
    else # We do not have a backend droplet anymore
      Router.log.info "Backend connection dropped"
      terminate_app_conn
      close_connection # Should we retry here?
    end
  end

  # We have the HTTP Headers complete from the client
  def on_headers_complete(headers)
    return close_connection unless headers and host = headers[HOST_HEADER]

    # Support for HTTP/1.1 connection reuse and possible pipelining
    @close_connection_after_request = (@parser.http_version.to_s == HTTP_11) ? false : true

    # Support for Connection:Keep-Alive requests on HTTP/1.0, e.g. ApacheBench
    @close_connection_after_request = false if (headers[CONNECTION_HEADER] == KEEP_ALIVE)

    @trace = (headers[VCAP_TRACE_HEADER] == Router.trace_key)

    # Update # of requests..
    VCAP::Component.varz[:requests] += 1

    # Clear and recycle previous state
    recycle_app_conn if @bound_app_conn
    @droplet = @bound_app_conn = nil

    # Lookup a Droplet
    unless droplets = Router.lookup_droplet(host)
      Router.log.debug "No droplet registered for #{host}"
      VCAP::Component.varz[:bad_requests] += 1
      send_data(Router.notfound_redirect || ERROR_404_RESPONSE)
      close_connection_after_writing
      return
    end

    Router.log.debug "#{droplets.size} servers available for #{host}"

    # Check for session state
    if VCAP_COOKIE =~ headers[COOKIE_HEADER]
      url, host, port = Router.decrypt_session_cookie($1)
      Router.log.debug "Client has __VCAP_ID__ for #{url}@#{host}:#{port}"
      # Check host?
      droplets.each { |droplet|
        # If we already now about them just update the timestamp..
        if(droplet[:host] == host && droplet[:port] == port)
          @droplet = droplet
          break;
        end
      }
      Router.log.debug "Client's __VCAP_ID__ is stale" unless @droplet
    end

    # pick a random backend unless selected from above already
    @droplet = droplets[rand*droplets.size] unless @droplet

    if @droplet[:tags]
      @droplet[:tags].each do |key, value|
        tag_metrics = VCAP::Component.varz[:tags][key][value]
        tag_metrics[:requests] += 1
      end
    end

    @droplet[:requests] += 1

    # Client tracking, override with header if its set (nginx to unix domain socket)
    _, client_ip = Socket.unpack_sockaddr_in(get_peername) unless @is_unix_socket
    client_ip = headers[REAL_IP_HEADER] if headers[REAL_IP_HEADER]

    @droplet[:clients][client_ip] += 1 if client_ip

    Router.log.debug "Routing on #{@droplet[:url]} to #{@droplet[:host]}:#{@droplet[:port]}"

    # Reuse an existing connection or create one.
    # Proxy the rest of the traffic without interference.
    Router.log.debug "Droplet has #{@droplet[:connections].size} pooled connections waiting.."
    @bound_app_conn = @droplet[:connections].pop
    if (@bound_app_conn && !@bound_app_conn.error?)
      Router.log.debug "Reusing pooled AppConnection.."
      @bound_app_conn.rebind(self, @headers)
    else
      host, port = @droplet[:host], @droplet[:port]
      @bound_app_conn = EM.connect(host, port, AppConnection, self, @headers, @droplet)
    end

  end

  def on_message_complete
    @parser = nil
    :stop
  end

  def receive_data(data)
    # Parser is created after headers have been received and processed.
    # If it exists we are continuing the processing of body fragments.
    # Allow the parser to process to signal proper end of message, e.g. chunked, etc
    return process_request_body_chunk(data) if @parser

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
      process_request_body_chunk(@buf) if @parser
      @buf = @headers = nil
    end

  rescue Http::Parser::Error => e
    Router.log.debug "HTTP Parser error on request: #{e}"
    close_connection
  end

  def unbind
    Router.log.debug "Unbinding client connection"
    VCAP::Component.varz[:client_connections] = Router.client_connection_count -= 1
    Router.log.debug Router.connection_stats
    Router.log.debug "------------"
    @close_connection_after_request ? terminate_app_conn : recycle_app_conn
  end

end
