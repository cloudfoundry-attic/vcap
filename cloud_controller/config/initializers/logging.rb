require 'vcap/logging'

VCAP::Logging.setup_from_config(AppConfig[:logging])
CloudController.logger = VCAP::Logging.logger('cc')
