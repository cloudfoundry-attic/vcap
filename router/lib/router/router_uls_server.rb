
require "sinatra/base"

class RouterULSServer < Sinatra::Base
  disable :show_exceptions

  get "/" do
    uls_response = {}
    VCAP::Component.varz[:requests] += 1

    uls_req = JSON.parse(request.body.read, :symbolize_keys => true)
    stats, url = uls_req[ULS_STATS_UPDATE], uls_req[ULS_HOST_QUERY]

    if stats then
      update_uls_stats(stats)
    end

    if url then
      # Lookup a droplet
      unless droplets = Router.lookup_droplet(url)
        Router.log.debug "No droplet registered for #{url}"
        raise Sinatra::NotFound
      end

      # Pick a droplet based on original backend addr or pick a droplet randomly
      droplet = check_original_droplet(droplets, uls_req[ULS_BACKEND_ADDR])
      droplet = droplets[rand*droplets.size] unless droplet
      Router.log.debug "Routing #{droplet[:url]} to #{droplet[:host]}:#{droplet[:port]}"

      # Update droplet stats
      update_droplet_stats(droplet)

      uls_req_tags = Base64.encode64(Marshal.dump(droplet[:tags])).strip if droplet[:tags]
      uls_response = {
        ULS_BACKEND_ADDR => "#{droplet[:host]}:#{droplet[:port]}",
        ULS_REQUEST_TAGS => "#{uls_req_tags}",
        ULS_ROUTER_IP    => "#{Router.inet}"
      }
    end

    uls_response.to_json
  end

  not_found do
    VCAP::Component.varz[:bad_requests] += 1
    "VCAP ROUTER: 404 - DESTINATION NOT FOUND"
  end

  error JSON::ParserError do
    VCAP::Component.varz[:bad_requests] += 1
    "VCAP ROUTER: 500 - CANNOT PARSE PAYLOAD"
  end

  error do
    VCAP::Component.varz[:bad_requests] += 1
    "VCAP ROUTER: 500 - UNKNOWN"
  end

  protected

  def check_original_droplet(droplets, backend_addr)
    droplet = nil
    if backend_addr
      host, port = backend_addr.split(":")
      Router.log.debug "request has __VCAP_ID__ cookie for #{host}:#{port}"
      # Check host?
      droplets.each do |d|
        if(d[:host] == host && d[:port] == port.to_i)
          droplet = d; break
        end
      end
      Router.log.debug "request's __VCAP_ID__ is stale" unless @droplet
    end
    droplet
  end

  def update_uls_stats(stats)
    stats.each do |stat|
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

        end # tags
      end # stat[ULS_RESPONSE_STATUS]
    end # stats.each
  end

  def update_droplet_stats(droplet)
    if droplet[:tags]
      droplet[:tags].each do |key, value|
        tag_metrics = VCAP::Component.varz[:tags][key][value]
        tag_metrics[:requests] += 1
      end
    end

    droplet[:requests] += 1
  end
end
