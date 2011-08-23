# Copyright (c) 2009-2011 VMware, Inc.
require 'uri'

require 'services/api/const'
require 'json_message'

module VCAP
  module Services
    module Api

      class EmptyRequest < JsonMessage
      end
      EMPTY_REQUEST = EmptyRequest.new.freeze

      #
      # Tell the CloudController about a service
      # NB: Deleting an offering takes all args in the url
      #
      class ServiceOfferingRequest < JsonMessage
        required :label,       SERVICE_LABEL_REGEX
        required :url,         URI::regexp(%w(http))

        optional :description, String
        optional :info_url,    URI::regexp(%w(http https))
        optional :tags,        [String]
        optional :plans,       [String]
        optional :plan_options
        optional :binding_options
        optional :acls,        {'users' => [String], 'wildcards' => [String]}
        optional :active
        optional :timeout,     Integer
      end

      class HandleUpdateRequest < JsonMessage
        required :service_id, String
        required :configuration
        required :credentials
      end

      class ListHandlesResponse < JsonMessage
        required :handles, [JsonSchema::WILDCARD]
      end

      #
      # Provision a service instance
      # NB: Unprovision takes all args in the url
      #
      class ProvisionRequest < JsonMessage
        required :label, SERVICE_LABEL_REGEX
        required :name,  String
        required :plan,  String

        optional :plan_option
      end

      class ProvisionResponse < JsonMessage
        required :service_id, String
        required :data
        required :credentials
      end

      #
      # Bind a previously provisioned service to an app
      #
      class CloudControllerBindRequest < JsonMessage
        required :service_id, String
        required :app_id,     Integer
        required :binding_options
      end

      class GatewayBindRequest < JsonMessage
        required :service_id,    String
        required :label,         String
        required :binding_options
      end

      class GatewayUnbindRequest < JsonMessage
        required :service_id,    String
        required :handle_id,     String
        required :binding_options
      end

      class CloudControllerBindResponse < JsonMessage
        required :label,         SERVICE_LABEL_REGEX
        required :binding_token, String
      end

      class GatewayBindResponse < JsonMessage
        required :service_id, String
        required :configuration
        required :credentials
      end

      # Bind app_name using binding_token
      class BindExternalRequest < JsonMessage
        required :binding_token, String
        required :app_id,        Integer
      end

      class BindingTokenRequest < JsonMessage
        required :service_id, String
        required :binding_options
      end

    end
  end
end
