--------------------------------------------------------------------------------
-- Title:               uls.lua
-- Description:         Helper for nginx talking to uls(Upstream Locator Server)
-- Legal:               Copyright (c) 2011 VMware, Inc.
--------------------------------------------------------------------------------

-- import dependencies
local cjson = require("cjson")
require("tablesave")

module("uls", package.seeall)
_VERSION = '1.0'

VCAP_SESSION_ID        = "__VCAP_ID__"
VCAP_COOKIE            = "__VCAP_ID__=([^;]+)"
SET_COOKIE_HEADER      = "Set-Cookie"
STICKY_SESSIONS        = "JSESSIONID"
COOKIE_HEADER          = "Cookie"
HOST_HEADER            = "Host"
VCAP_BACKEND_HEADER    = "X-Vcap-Backend"
VCAP_ROUTER_HEADER     = "X-Vcap-Router"
VCAP_TRACE_HEADER      = "X-Vcap-Trace"

-- From nginx to uls
ULS_HOST_QUERY         = "host"
ULS_STATS_UPDATE       = "stats"
ULS_STATS_LATENCY      = "response_latency"
ULS_STATS_SAMPLES      = "response_samples"
ULS_STATS_CODES        = "response_codes"
ULS_STICKY_SESSION     = "sticky_session"
-- For both diretion
-- When ULS_BACKEND_ADDR sent from nginx to uls, it means sticky address
ULS_BACKEND_ADDR       = "backend_addr"
ULS_REQEST_TAGS        = "request_tags"
ULS_ROUTER_IP          = "router_ip"

--[[
  Message between nginx and uls (as http body)
  nginx -> uls
  {
    "host":         api.vcap.me,
    "backend_addr": 10.117.9.178:9022,
    "stats": [
      {
        "request_tags": xxx,
        "response_latency": xxx,
        "response_samples": xxx,
        "response_codes": {
          {"responses_xxx":xxx},
          {"responses_2xx":xxx}
        }
      },
      {
        "request_tags": xxx,
        "response_latency": xxx,
        "response_samples": xxx,
        "response_codes": {
          {"responses_xxx":xxx},
          {"responses_2xx":xxx}
          {"responses_5xx":xxx},
        }
      }
    ]
  }

  nginx <- uls
  {
    "backend_addr": xxx,
    "request_tags": xxx,
    "router_ip": xxx
  }
--]]

-- Per nginx worker global variables
-- We don't need any lock as nginx callback in a single thread
stats_not_synced = {}
request_num = 0

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

-- Retrieve ip:port if the input cookies have vcap cookie
function retrieve_vcap_sticky_session(cookies)
  if not cookies then return nil end
  if type(cookies) ~= "table" then cookies = {cookies} end

  for _, val in ipairs(cookies) do
    local i, j = string.find(val, VCAP_COOKIE)
    if i then
      assert(i + string.len(VCAP_SESSION_ID) + 1 < j)
      local sticky = string.sub(val, i + string.len(VCAP_SESSION_ID) + 1, j)
      return sticky
    end
  end
  return nil
end

-- Save per request stats into per worker store
function vcap_store_stats(req_tags, response_code, latency)

  request_num = request_num + 1
  local stats = stats_not_synced[req_tags]
  if not stats then
    stats = {[ULS_STATS_CODES] = {},
             [ULS_STATS_LATENCY] = 0,
             [ULS_STATS_SAMPLES] = 0}

    stats_not_synced[req_tags] = stats
  end

  local response_code_metric = "responses_xxx"
  if response_code >= 200 and response_code < 300 then
    response_code_metric = "responses_2xx"
  elseif response_code >= 300 and response_code < 400 then
    response_code_metric = "responses_3xx"
  elseif response_code >= 400 and response_code < 500 then
    response_code_metric = "responses_4xx"
  elseif response_code >= 500 and response_code < 600 then
    response_code_metric = "responses_5xx"
  end

  if not stats[ULS_STATS_CODES][response_code_metric] then
    stats[ULS_STATS_CODES][response_code_metric] = 1
  else
    stats[ULS_STATS_CODES][response_code_metric] =
      stats[ULS_STATS_CODES][response_code_metric] + 1
  end

  local t = stats[ULS_STATS_LATENCY] * stats[ULS_STATS_SAMPLES] + latency
  stats[ULS_STATS_SAMPLES] = stats[ULS_STATS_SAMPLES] + 1
  stats[ULS_STATS_LATENCY] = t / stats[ULS_STATS_SAMPLES]

end

-- Assemble saved stats to return to the caller, then cleanup
function serialize_request_statistics()
  if request_num == 0 then return nil end

  local stats = {}
  for k, v in pairs(stats_not_synced) do
    table.insert(stats, {[ULS_REQEST_TAGS] = k,
                         [ULS_STATS_LATENCY] = v[ULS_STATS_LATENCY],
                         [ULS_STATS_SAMPLES] = v[ULS_STATS_SAMPLES],
                         [ULS_STATS_CODES] = v[ULS_STATS_CODES]})
  end

  -- clean stats
  request_num = 0
  stats_not_synced = {}
  return stats
end

function vcap_handle_cookies(ngx)
  local cookies = ngx.header.set_cookie
  if not cookies then return end

  if type(cookies) ~= "table" then cookies = {cookies} end
  local sticky = false
  for _, val in ipairs(cookies) do
    local i, j = string.find(val:upper(), STICKY_SESSIONS)
    if i then
      sticky = true
      break
    end
  end
  if not sticky then return end

  local vcap_cookie = VCAP_SESSION_ID.."="..ngx.var.sticky

  ngx.log(ngx.DEBUG, "generate cookie:"..vcap_cookie.." for resp from:"..
          ngx.var.backend_addr)
  table.insert(cookies, vcap_cookie)
  -- ngx.header.set_cookie incorrectly makes header to "set-cookie",
  -- so workaround to set "Set-Cookie" directly
  -- ngx.header.set_cookie = cookies
  ngx.header["Set-Cookie"] = cookies
end

function vcap_add_trace_header(backend_addr, router_ip)
  ngx.header[VCAP_BACKEND_HEADER] = backend_addr
  ngx.header[VCAP_ROUTER_HEADER] = router_ip
end

function generate_stats_request()
  local uls_req_spec = {}
  local req_stats = uls.serialize_request_statistics()
  if req_stats then
    uls_req_spec[ULS_STATS_UPDATE] = req_stats
  end
  return cjson.encode(uls_req_spec)
end

function pre_process_subrequest(ngx, trace_key)
  ngx.var.timestamp = ngx.time()

  if string.len(ngx.var.http_host) == 0 then
    ngx.exit(ngx.HTTP_BAD_REQUEST)
  end

  if ngx.req.get_headers()[VCAP_TRACE_HEADER] == trace_key then
    ngx.var.trace = "Y"
  end
end

function generate_uls_request(ngx)
  local uls_req_spec = {}

  -- add host in request
  uls_req_spec[uls.ULS_HOST_QUERY] = ngx.var.http_host

  -- add sticky session in request
  local uls_sticky_session = retrieve_vcap_sticky_session(
          ngx.req.get_headers()[COOKIE_HEADER])
  if uls_sticky_session then
    uls_req_spec[ULS_STICKY_SESSION] = uls_sticky_session
    ngx.log(ngx.DEBUG, "req sticks to backend session:"..uls_sticky_session)
  end

  -- add status update in request
  local req_stats = uls.serialize_request_statistics()
  if req_stats then
    uls_req_spec[ULS_STATS_UPDATE] = req_stats
  end

  return cjson.encode(uls_req_spec)
end

function post_process_subrequest(ngx, res)
  if res.status ~= 200 then
    ngx.exit(ngx.HTTP_NOT_FOUND)
  end

  local msg = cjson.decode(res.body)
  ngx.var.backend_addr = msg[ULS_BACKEND_ADDR]
  ngx.var.uls_req_tags = msg[ULS_REQEST_TAGS]
  ngx.var.router_ip    = msg[ULS_ROUTER_IP]
  ngx.var.sticky       = msg[ULS_STICKY_SESSION]

  ngx.log(ngx.DEBUG, "route "..ngx.var.http_host.." to "..ngx.var.backend_addr)
end

function post_process_response(ngx)
  local latency = ( ngx.time() - ngx.var.timestamp ) * 1000
  vcap_store_stats(ngx.var.uls_req_tags, ngx.status, latency)

  if ngx.var.trace == "Y" then
    vcap_add_trace_header(ngx.var.backend_addr, ngx.var.router_ip)
  end

  vcap_handle_cookies(ngx)
end

