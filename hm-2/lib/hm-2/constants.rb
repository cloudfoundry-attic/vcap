require 'set'

module HealthManager2


  #restart priorities
  LOW_PRIORITY = 1
  NORMAL_PRIORITY = 1000
  HIGH_PRIORITY = 1_000_000


  #intervals
  EXPECTED_STATE_UPDATE = 10
  ANALYSIS_DELAY = 5
  DROPLET_ANALYSIS = 10
  REQUEST_QUEUE = 1
  DEA_TIMEOUT_INTERVAL = 15
  NATS_REQUEST_TIMEOUT = 5
  RUN_LOOP_INTERVAL = 2


  #app states
  DOWN              = 'DOWN'
  STARTED           = 'STARTED'
  STOPPED           = 'STOPPED'
  CRASHED           = 'CRASHED'
  STARTING          = 'STARTING'
  RUNNING           = 'RUNNING'
  FLAPPING          = 'FLAPPING'
  DEA_SHUTDOWN      = 'DEA_SHUTDOWN'
  DEA_EVACUATION    = 'DEA_EVACUATION'
  APP_STABLE_STATES = Set.new([STARTED, STOPPED])
  RUNNING_STATES    = Set.new([STARTING, RUNNING])
  RESTART_REASONS   = Set.new([CRASHED, DEA_SHUTDOWN, DEA_EVACUATION])

  #environment options
  NATS_URI          = 'NATS_URI'
  LOG_LEVEL         = 'LOG_LEVEL'
  HM_SHADOW         = 'HM_SHADOW'
end
