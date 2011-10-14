module CollabSpaces

  class OrganizationService

    def create_organization(organization_name)

      #if(invalid_name?(organization_name))
      #  CloudController.logger.error("Invalid organization name", :tags => [:collab_spaces_failure])
      #  raise CloudError.new(CloudError::BAD_REQUEST)
      #end

      CloudController.logger.debug("Creating org #{organization_name}")
      org = Organization.new :name => organization_name
      CloudController.logger.debug("Org created is #{org.inspect}");

      begin
        org.save!
      rescue => e
        CloudController.logger.debug("Failed to create an org " + e.to_s);
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      if(!org.valid?)
        CloudController.logger.debug("Org is not valid #{org.inspect}")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      org

    end


    def delete_organization(organization_name)

      org_to_be_deleted = Organization.find_by_name(organization_name)
      if(!org_to_be_deleted.nil? && org_to_be_deleted.valid?)
        Organization.delete(org_to_be_deleted.id)
      else
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

    end

    def find_organization(organization_name)

      Organization.find_by_name(organization_name)

    end


    def invalid_name?(organization_name)

      #Found something other than a-zA-Z0-9 in the string
      !!(/^[a-zA-Z0-9]/ =~ organization_name)

    end

  end

  class ResourceService

    def create_resource(organization, resource_type)

      if(organization.nil? || !organization.valid?)
        CloudController.logger.debug("Org is nil or not valid")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      if(resource_type.nil? || resource_type.empty?)
        CloudController.logger.debug("Empty resource type")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      CloudController.logger.debug("Creating resource of type #{resource_type} for org #{organization.inspect}")

      resource = Resource.new :organization => organization, :type => resource_type
      CloudController.logger.debug("Resource created is #{resource.inspect}");

      begin
        resource.save!
      rescue => e
        CloudController.logger.debug("Failed to create the resource: Error " + e.to_s);
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      resource

    end

    def delete_resource(resource_id)

      resource_to_be_deleted = Resource.find_by_id(resource_id)
      if(!resource_to_be_deleted.nil? && resource_to_be_deleted.valid?)
        Resource.delete(resource_to_be_deleted.id)
      else
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

    end

  end

end
