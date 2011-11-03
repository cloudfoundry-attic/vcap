# Copyright (c) 2009-2011 VMware, Inc.

module ClientConnection

  HTTP_11 ='11'.freeze

  attr_reader :close_connection_after_request

  def initialize(is_unix_socket)
    Router.log.debug "Created uls Connection"
    @droplet = nil
    # Default to be on the safe side
    @close_connection_after_request = true
    @is_unix_socket = is_unix_socket
  end

  def post_init
    VCAP::Component.varz[:client_connections] = Router.client_connection_count += 1
    Router.log.debug Router.connection_stats
    Router.log.debug "------------"
    @parser = Http::Parser.new(self)
    self.comm_inactivity_timeout = 60.0
  end

  def connection_completed
    Router.log.debug "uls connection completed"
  end

  def receive_data(data)
    @parser << data
  rescue Http::Parser::Error => e
    Router.log.debug "HTTP Parser error on request: #{e}"
    close_connection
  end

  def on_message_begin
    @headers = nil
    @body = ''
  end

  def on_headers_complete(headers)
    @headers = @parser.headers
  end

  def on_body(chunk)
    @body << chunk
  end

  def on_message_complete
    # Support for HTTP/1.1 connection reuse and possible pipelining
    @close_connection_after_request = (@parser.http_version.to_s == HTTP_11) ? false : true

    # Support for Connection:Keep-Alive requests on HTTP/1.0, e.g. ApacheBench
    @close_connection_after_request = false if (@headers[CONNECTION_HEADER] == KEEP_ALIVE)

    # Update # of requests..
    VCAP::Component.varz[:requests] += 1

    @droplet = nil

    Router.log.debug "request body content:#{@body}"
    uls_req = JSON.parse(@body, :symbolize_keys => true)

    # Update request stats carried with this uls query
    if uls_req[ULS_STATS_UPDATE]
      uls_req[ULS_STATS_UPDATE].each do |stat|
        if stat[ULS_REQUEST_TAGS].length > 0
          tags = Marshal.load(Base64.decode64(stat[ULS_REQUEST_TAGS]))
        end

        latency = stat[ULS_RESPONSE_LATENCY]
        samples = stat[ULS_RESPONSE_SAMPLES]

        # We may find a better solution for latency
        1.upto samples do
          VCAP::Component.varz[:latency] << latency
        end

        stat[ULS_RESPONSE_STATUS].each_pair do |k, v|
          response_code_metric = k.to_sym
          VCAP::Component.varz[response_code_metric] += v
          if not tags then next end

          tags.each do |key, value|
            # In case some req tags of syncup state may be invalid at this time
            if not VCAP::Component.varz[:tags][key] or
               not VCAP::Component.varz[:tags][key][value]
               next
            end

            tag_metrics = VCAP::Component.varz[:tags][key][value]
            tag_metrics[response_code_metric] += v
            1.upto samples do
              tag_metrics[:latency] << latency
            end
          end
        end
      end
    end

    url = uls_req[ULS_HOST_QUERY]
    # In case a stats syncup only request
    if not url then
      if close_connection_after_request
        close_connection_after_writing
      end
      return
    end

    # Lookup a Droplet
    unless droplets = Router.lookup_droplet(url)
      Router.log.debug "No droplet registered for #{url}"
      VCAP::Component.varz[:bad_requests] += 1
      send_data(Router.notfound_redirect || ERROR_404_RESPONSE)
      close_connection_after_writing
      return
    end

    # Check for session state
    if uls_req[ULS_BACKEND_ADDR]
      host, port = uls_req[ULS_BACKEND_ADDR].split(":")
      Router.log.debug "request has __VCAP_ID__ cookie for #{host}:#{port}"
      # Check host?
      droplets.each { |droplet|
        if(droplet[:host] == host && droplet[:port] == port.to_i)
          @droplet = droplet
          break;
        end
      }
      Router.log.debug "request's __VCAP_ID__ is stale" unless @droplet
    end

    # Pick a random backend unless selected from above already
    @droplet = droplets[rand*droplets.size] unless @droplet

    if @droplet[:tags]
      @droplet[:tags].each do |key, value|
        tag_metrics = VCAP::Component.varz[:tags][key][value]
        tag_metrics[:requests] += 1
      end
      uls_req_tags = Base64.encode64(Marshal.dump(@droplet[:tags])).strip
    end

    @droplet[:requests] += 1

    Router.log.debug "Routing #{@droplet[:url]} to #{@droplet[:host]}:#{@droplet[:port]}"

    # send upstream addr back to nginx
    uls_response = {
      ULS_BACKEND_ADDR => "#{@droplet[:host]}:#{@droplet[:port]}",
      ULS_REQUEST_TAGS => "#{uls_req_tags}",
      ULS_ROUTER_IP    => "#{Router.inet}"
    }.to_json
    send_data(HTTP_200_RESPONSE + "#{uls_response}")

    if close_connection_after_request
      close_connection_after_writing
    end

  rescue JSON::ParserError
    send_data(HTTP_400_RESPONSE)
    close_connection_after_writing
  end

  def unbind
    Router.log.debug "Unbinding client connection"
    VCAP::Component.varz[:client_connections] = Router.client_connection_count -= 1
    Router.log.debug Router.connection_stats
    Router.log.debug "------------"
  end

end
