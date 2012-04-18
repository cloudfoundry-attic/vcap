# Copyright (c) 2009-2011 VMware, Inc.
# HTTP Header processing
HOST_HEADER            = 'Host'.freeze
CONNECTION_HEADER      = 'Connection'.freeze
KEEP_ALIVE             = 'keep-alive'.freeze

#STICKY_SESSIONS        = /(JSESSIONID)/i

VCAP_BACKEND_HEADER    = 'X-Vcap-Backend'
VCAP_ROUTER_HEADER     = 'X-Vcap-Router'
VCAP_TRACE_HEADER      = 'X-Vcap-Trace'

ULS_HOST_QUERY         = :"host"
ULS_STATS_UPDATE       = :"stats"
ULS_REQUEST_TAGS       = :"request_tags"
ULS_RESPONSE_STATUS    = :"response_codes"
ULS_RESPONSE_SAMPLES   = :"response_samples"
ULS_RESPONSE_LATENCY   = :"response_latency"
ULS_BACKEND_ADDR       = :"backend_addr"
ULS_ROUTER_IP          = :"router_ip"
ULS_STICKY_SESSION     = :"sticky_session"

# Max Connections to Pool
MAX_POOL = 32

# Timers for sweepers

RPS_SWEEPER       = 2   # Requests rate sweeper
START_SWEEPER     = 30  # Timer to publish router.start for refreshing state
CHECK_SWEEPER     = 30  # Check time for watching health of registered droplet
MAX_AGE_STALE     = 120 # Max stale age, unregistered if older then 2 minutes

# 200 Response
HTTP_200_RESPONSE = "HTTP/1.1 200 OK\r\n\r\n".freeze

# 400 Response
ERROR_400_RESPONSE = "HTTP/1.1 400 Bad Request\r\nConnection: close\r\n\r\n".freeze

# 404 Response
ERROR_404_RESPONSE = "HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n" +
                     "VCAP ROUTER: 404 - DESTINATION NOT FOUND\r\n".freeze
