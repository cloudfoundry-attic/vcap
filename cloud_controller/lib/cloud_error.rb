# TODO - Enforce sane numbering of these errors.

class CloudError < StandardError
  attr_reader :status, :value
  def initialize(info, *args)
    @error_code, @status, msg = *info
    @message = sprintf(msg, *args)
    super(@message)
  end

  def to_json(options = nil)
    Yajl::Encoder.encode({:code => @error_code, :description => @message})
  end

  HTTP_BAD_REQUEST           = 400
  HTTP_FORBIDDEN             = 403
  HTTP_NOT_FOUND             = 404
  HTTP_INTERNAL_SERVER_ERROR = 500
  HTTP_BAD_GATEWAY           = 502

  # HTTP / JSON errors
  BAD_REQUEST = [100, HTTP_BAD_REQUEST, "Bad request"]
  DATABASE_ERROR = [101, HTTP_INTERNAL_SERVER_ERROR, "Error talking with the database"]
  LOCKING_ERROR = [102, HTTP_BAD_REQUEST, "Optimistic locking failure"]
  SYSTEM_ERROR = [111, HTTP_INTERNAL_SERVER_ERROR, "System Exception Encountered"]

  # User-level errors
  FORBIDDEN = [200, HTTP_FORBIDDEN, "Operation not permitted"]
  USER_NOT_FOUND = [201, HTTP_FORBIDDEN, "User not found"]

  # Application-level errors
  APP_INVALID = [300, HTTP_BAD_REQUEST, "Invalid application description"]
  APP_NOT_FOUND = [301, HTTP_NOT_FOUND, "Application not found"]
  APP_NO_RESOURCES = [302, HTTP_NOT_FOUND, "Couldn't find a place to run an app"]
  APP_FILE_NOT_FOUND = [303, HTTP_NOT_FOUND, "Could not find : '%s'"]
  APP_INSTANCE_NOT_FOUND = [304, HTTP_BAD_REQUEST, "Could not find instance: '%s'"]
  APP_STOPPED = [305, HTTP_BAD_REQUEST, "Operation not permitted on a stopped app"]
  APP_FILE_ERROR = [306, HTTP_INTERNAL_SERVER_ERROR, "Error retrieving file '%s'"]
  APP_INVALID_RUNTIME = [307, HTTP_BAD_REQUEST, "Invalid runtime specification [%s] for framework: '%s'"]
  APP_INVALID_FRAMEWORK = [308, HTTP_BAD_REQUEST, "Invalid framework description: '%s'"]

  # Bits
  RESOURCES_UNKNOWN_PACKAGE_TYPE = [400, HTTP_BAD_REQUEST, "Unknown package type requested: \"%\""]
  RESOURCES_MISSING_RESOURCE = [401, HTTP_BAD_REQUEST, "Could not find the requested resource"]

  # Services
  SERVICE_NOT_FOUND = [500, HTTP_NOT_FOUND, "Service not found"]
  BINDING_NOT_FOUND = [501, HTTP_NOT_FOUND, "Binding not found"]
  TOKEN_NOT_FOUND   = [502, HTTP_NOT_FOUND, "Token not found"]
  SERVICE_GATEWAY_ERROR = [503, HTTP_BAD_GATEWAY, "Unexpected response from service gateway"]
  ACCOUNT_TOO_MANY_SERVICES = [504, HTTP_FORBIDDEN, "Too many Services provisioned: %s, you're allowed: %s"]

  # Account Capacity
  ACCOUNT_NOT_ENOUGH_MEMORY = [600, HTTP_FORBIDDEN, "Not enough memory capacity, you're allowed: %s"]
  ACCOUNT_APPS_TOO_MANY = [601, HTTP_FORBIDDEN, "Too many applications: %s, you're allowed: %s"]
  ACCOUNT_APP_TOO_MANY_URIS = [602, HTTP_FORBIDDEN, "Too many URIs: %s, you're allowed: %s"]

  # URIs
  URI_INVALID = [700, HTTP_BAD_REQUEST, "Invalid URI: \"%s\""]
  URI_ALREADY_TAKEN = [701, HTTP_BAD_REQUEST, "The URI: \"%s\" has already been taken or reserved"]
  URI_NOT_ALLOWED = [702, HTTP_FORBIDDEN, "External URIs are not enabled for this account"]

end
