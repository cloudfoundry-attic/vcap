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
        required :url,         URI::regexp(%w(http https))

        optional :description, String
        optional :info_url,    URI::regexp(%w(http https))
        optional :tags,        [String]
        optional :plans,       [String]
        optional :plan_options
        optional :binding_options
        optional :acls
        optional :active
        optional :timeout,     Integer
      end

      class BrokeredServiceOfferingRequest < JsonMessage
        required :label,        SERVICE_LABEL_REGEX
        required :options,      [{"name" => String, "credentials" => Hash}]
        optional :description,  String
      end

      class HandleUpdateRequest < JsonMessage
        required :service_id, String
        required :configuration
        required :credentials
      end

      class ListHandlesResponse < JsonMessage
        required :handles, [::JsonSchema::WILDCARD]
      end

      class ListBrokeredServicesResponse < JsonMessage
        required :brokered_services, [{"label" => String, "description" => String, "acls" => {"users" => [String], "wildcards" => [String]}}]
      end

      #
      # Provision a service instance
      # NB: Unprovision takes all args in the url
      #
      class CloudControllerProvisionRequest < JsonMessage
        required :label, SERVICE_LABEL_REGEX
        required :name,  String
        required :plan,  String

        optional :plan_option
      end

      class GatewayProvisionRequest < JsonMessage
        required :label, SERVICE_LABEL_REGEX
        required :name,  String
        required :plan,  String
        required :email, String

        optional :plan_option
      end

      class GatewayProvisionResponse < JsonMessage
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
        required :email,         String
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

      class Snapshot < JsonMessage
        required :snapshot_id,  String
        required :date,  String
        required :size,  Integer
      end

      class SnapshotList < JsonMessage
        required :snapshots,  [::JsonSchema::WILDCARD]
      end

      class Job < JsonMessage
        required :job_id,  String
        required :status,  String
        required :start_time, String
        optional :description, String
        optional :complete_time, String
        optional :result, ::JsonSchema::WILDCARD
      end

      class SerializedURL < JsonMessage
        required :url, URI::regexp(%w(http https))
      end

      class SerializedData < JsonMessage
        required :data,  String
      end
    end
  end
end
