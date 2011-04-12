# Copyright (c) 2009-2011 VMware, Inc.
# HTTP Header processing
HOST_HEADER            = 'Host'.freeze
CONNECTION_HEADER      = 'Connection'.freeze
REAL_IP_HEADER         = 'X-Real_IP'.freeze
HTTP_HEADERS_END       = "\r\n\r\n".freeze
HTTP_HEADERS_END_SIZE  = HTTP_HEADERS_END.bytesize
KEEP_ALIVE             = 'keep-alive'.freeze
SET_COOKIE_HEADER      = 'Set-Cookie'.freeze
COOKIE_HEADER          = 'Cookie'.freeze
CR_LF                  = "\r\n".freeze

STICKY_SESSIONS        = /(JSESSIONID)/i

VCAP_SESSION_ID        = '__VCAP_ID__'.freeze
VCAP_COOKIE            = /__VCAP_ID__=([^;]+)/

VCAP_BACKEND_HEADER    = 'X-Vcap-Backend'
VCAP_ROUTER_HEADER     = 'X-Vcap-Router'
VCAP_TRACE_HEADER      = 'X-Vcap-Trace'

# Max Connections to Pool
MAX_POOL = 32

# Timers for sweepers

RPS_SWEEPER       = 2   # Requests rate sweeper
START_SWEEPER     = 30  # Timer to publish router.start for refreshing state
CHECK_SWEEPER     = 30  # Check time for watching health of registered drop
MAX_AGE_STALE     = 120 # Max stale age, unregistered if older then 2 minutes

# 404 Response
ERROR_404_RESPONSE="HTTP/1.1 404 Not Found\r\nConnection: close\r\n\r\n" +
                   "VCAP ROUTER: 404 - DESTINATION NOT FOUND\r\n".freeze

