require 'json_message'

module LegacyVmcMessages

  class ProvisionRequest < JsonMessage
    required :name,    String
    required :vendor,  String
    required :version, String
    required :tier,    String

    optional :type,    String
    optional :meta,    Hash
    optional :id
    optional :options, Hash
  end

end
