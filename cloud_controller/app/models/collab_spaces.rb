module CollabSpaces

  class CollabSpacesService

    attr_accessor :authenticated_user
    attr_accessor :org
    attr_accessor :project

    def initialize(param_hash)

      @authenticated_user = param_hash[:authenticated_user]
      @org = param_hash[:org]
      @project = param_hash[:project]

      if(@org.nil?)
        @org = @authenticated_user
      end

      if(@project.nil?)
        @project = :all.to_s
      end

    end

  end

  class OrganizationService < CollabSpacesService

    def create_organization(param_hash)

      @name = param_hash[:name]
      if(@name.nil? || @name.empty?)
        CloudController.logger.debug("Could not find " + :name)
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      CloudController.logger.debug("Creating org #{@name}")
      org = Organization.new(:authenticated_user => @authenticated_user, :name => @name)
      CloudController.logger.debug("Org to be created is #{org.inspect}")

      org.transaction do
        begin
          org.save!
        rescue => e
          CloudController.logger.debug("Failed to create an org " + e.to_s)
          raise CloudError.new(CloudError::BAD_REQUEST)
        end
        if(!org.valid?)
          CloudController.logger.debug("Org is not valid #{org.inspect}")
          raise CloudError.new(CloudError::BAD_REQUEST)
        end

        #Create the default 'all' project
        proj_service = ::CollabSpaces::ProjectManagementService.new(:authenticated_user => @authenticated_user,
                                                                  :org => nil,
                                                                  :project => nil,
                                                                  :name => @name)
        default_project = proj_service.create_project(@name, org, :all)

        if(!default_project.nil? && default_project.valid?)
          CloudController.logger.debug("Project created #{default_project.inspect}")
        else
          raise CloudError.new(CloudError::SYSTEM_ERROR)
        end

        #Create the admin role in the all project and add the user creating the org to that role

        #Create the default 'admin' role and add the user to the role
        role_service = ::CollabSpaces::RoleService.new(:authenticated_user => @authenticated_user,
                                                     :org => nil,
                                                     :project => nil,
                                                     :name => @name)
        admin_role = role_service.create_role(@name, default_project, :admin)

        if(!admin_role.nil? && admin_role.valid?)
          CloudController.logger.debug("Role created #{admin_role.inspect}")
        else
          raise CloudError.new(CloudError::SYSTEM_ERROR)
        end

        admin_role.add_user(@name)
        all_permissions = [:CREATE, :READ, :UPDATE, :DELETE]
        admin_role.update_acl(org.immutable_id, all_permissions)
        admin_role.update_acl(default_project.immutable_id, all_permissions)
        admin_role.update_acl(admin_role.immutable_id, all_permissions)

        begin
          admin_role.save!
        rescue => e
          CloudController.logger.debug("Failed to update the admin role " + e.to_s)
          raise CloudError.new(CloudError::SYSTEM_ERROR)
        end

        if(!admin_role.valid?)
          CloudController.logger.debug("Role is not valid #{admin_role.inspect}")
          raise CloudError.new(CloudError::SYSTEM_ERROR)
        end

      end

      org

    end


    def delete_organization(param_hash)

      @name = param_hash[:name]

      if(@name.nil? || @name.empty?)
        CloudController.logger.debug("Could not find " + :name)
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      org_to_be_deleted = Organization.find(:name => @name)
      if(!org_to_be_deleted.nil? && org_to_be_deleted.valid?)
        Organization.destroy_all(org_to_be_deleted.id)
        CloudController.logger.debug("#{organization_name} deleted")
      else
        CloudController.logger.debug("Could not find organization #{organization_name}")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

    end


    def find_organization(param_hash)

      if(!(param_hash.respond_to? "keys") && !(param_hash.respond_to? "values"))
        CloudController.logger.debug("Invalid parameters to find_organization")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      #we don't want anyone using the internal id
      if(!param_hash[:id].nil?)
        param_hash[:immutable_id] = param_hash[:id]
        param_hash.delete(:id)
      end

      method_name = "find_by_" + param_hash.keys.join("_and_")

      CloudController.logger.debug("Find method name #{method_name}")

      if(Organization.respond_to? method_name)
        Organization.send(method_name, param_hash.values)
      else
        CloudController.logger.debug("Invalid parameters to find_organization")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

    end


    def invalid_name?(organization_name)

      #Found something other than a-zA-Z0-9 in the string
      !!(/^[a-zA-Z0-9]/ =~ organization_name)

    end

  end

  class ProjectManagementService < CollabSpacesService

    def create_project(user_token, organization, project_name)

      begin

        project = Project.new(:owner => organization)
        project.name = project_name
        project.metadata_json = { :owner => organization.immutable_id }.to_json

        project.save!
        CloudController.logger.debug("Project created is #{project.inspect}")
      rescue => e
        CloudController.logger.debug("Failed to create the project: Error " + e.to_s)
        raise e
      end

      project

    end

    def delete_project(project_id)

      begin

        project_to_be_deleted = Project.find(:id => project_id)
        if(!project_to_be_deleted.nil? && project_to_be_deleted.valid?)
          Project.delete(project_to_be_deleted.id)
        else
          raise CloudError.new(CloudError::BAD_REQUEST)
        end

      rescue => e

        CloudController.logger.debug("Failed to delete the project: Error " + e.to_s)
        raise e

      end

    end

    def find_project(param_hash)

      if(!(param_hash.respond_to? "keys") && !(param_hash.respond_to? "values"))
        CloudController.logger.debug("Invalid parameters to find_project")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      #we don't want anyone using the internal id
      if(!param_hash[:id].nil?)
        param_hash[:immutable_id] = param_hash[:id]
        param_hash.delete(:id)
      end

      method_name = "find_by_" + param_hash.keys.join("_and_")

      CloudController.logger.debug("Find method name #{method_name}")

      if(Project.respond_to? method_name)
        Project.send(method_name, param_hash.values)
      else
        CloudController.logger.debug("Invalid parameters to find_project")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

    end

  end

  class ResourceService < CollabSpacesService


    # Method is used to create a resource
    #
    # @param organization_id - Id of the organization that owns this resource
    # @param resource_type - Type of the resource as a string
    # @param metadata - Resource metadata as a hash
    #
    # @returns resource object
    #
    def create_resource(user_token, organization_id, resource_type, resource_name, metadata)

      #::CollabSpaces::Authorizer::can user, :create, ::App, org, project

      if(resource_type.nil? || resource_type.empty?)
        CloudController.logger.debug("Empty resource type")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      CloudController.logger.debug("Creating resource of type #{resource_type} for org #{organization_id}")

      begin
        organization = OrganizationService.new(:authenticated_user => user_token).find_organization(:id => organization_id)
      rescue => e
        CloudController.logger.debug("Failed to create the resource: Error " + e.to_s)

      end

      if(organization.nil?)
        CloudController.logger.debug("Could not find organization #{organization_id}")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      resource = Resource.new(:authenticated_user => @authenticated_user,
                             :org => @org,
                             :project => @project,
                             :owner => organization)

      resource.type = resource_type
      resource.name = resource_name

      begin

        if(!metadata.nil?)
          if(metadata.respond_to? to_json)
            resource.metadata_json = metadata.to_json
          else
            resource.metadata_json = metadata
          end
        end
        resource.save!
        CloudController.logger.debug("Resource created is #{resource.inspect}")
      rescue => e
        CloudController.logger.debug("Failed to create the resource: Error " + e.to_s)
        raise e
      end

      resource

    end

    def delete_resource(resource_id)

      #::CollabSpaces::Authorizer::can user, :delete, ::App, org, project

      resource_to_be_deleted = Resource.find(:id => resource_id)
      if(!resource_to_be_deleted.nil? && resource_to_be_deleted.valid?)
        Resource.delete(resource_to_be_deleted.id)
      else
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

    end

    def find_resource(param_hash)

      if(!(param_hash.respond_to? "keys") && !(param_hash.respond_to? "values"))
        CloudController.logger.debug("Invalid parameters to find_resource")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      #we don't want anyone using the internal id
      if(!param_hash[:id].nil?)
        param_hash[:immutable_id] = param_hash[:id]
        param_hash.delete(:id)
      end

      method_name = "find_by_" + param_hash.keys.join("_and_")

      CloudController.logger.debug("Find method name #{method_name}")

      if(Resource.respond_to? method_name)
        Resource.send(method_name, param_hash.values)
      else
        CloudController.logger.debug("Invalid parameters to find_resource")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

    end

  end


  class RoleService

    def create_role(user_token, project, role_name)

      begin

        role = Role.new(:owner => project)
        role.name = role_name
        role.metadata_json = { :owner => project.immutable_id }.to_json

        role.save!
        CloudController.logger.debug("Role created is #{role.inspect}")
      rescue => e
        CloudController.logger.debug("Failed to create the role: Error " + e.to_s)
        raise e
      end

      role

    end

    def delete_role(role_id)

      begin

        role_to_be_deleted = Role.find(:id => role_id)
        if(!role_to_be_deleted.nil? && role_to_be_deleted.valid?)
          Role.delete(role_to_be_deleted.id)
        else
          raise CloudError.new(CloudError::BAD_REQUEST)
        end

      rescue => e

        CloudController.logger.debug("Failed to delete the role: Error " + e.to_s)
        raise e

      end

    end

    def find_role(param_hash)

      if(!(param_hash.respond_to? "keys") && !(param_hash.respond_to? "values"))
        CloudController.logger.debug("Invalid parameters to find_role")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

      #we don't want anyone using the internal id
      if(!param_hash[:id].nil?)
        param_hash[:immutable_id] = param_hash[:id]
        param_hash.delete(:id)
      end

      method_name = "find_by_" + param_hash.keys.join("_and_")

      CloudController.logger.debug("Find method name #{method_name}")

      if(Role.respond_to? method_name)
        Role.send(method_name, param_hash.values)
      else
        CloudController.logger.debug("Invalid parameters to find_role")
        raise CloudError.new(CloudError::BAD_REQUEST)
      end

    end

  end

end
