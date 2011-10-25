
class Resource < ActiveRecord::Base
  belongs_to :owner, :class_name => "Resource"

  before_create :set_immutable_id

  attr_accessor :authenticated_user
  attr_accessor :org
  attr_accessor :project

  #CREATE rights on the org are needed to create an app in that org
  def authorize_access_to

    CloudController.logger.debug("user is #{@authenticated_user}")
    CloudController.logger.debug("org is #{@org}")
    CloudController.logger.debug("project is #{@project}")

    CloudController.logger.debug("Owner is #{self.owner.inspect}");

    if(!self.owner.nil? && self.owner.type == :organization.to_s)

      owners_projects = self.owner.projects

      permission_set_for_user = []

      #find the projects for that user
      if(!owners_projects.nil?)

        CloudController.logger.debug("Owner's projects are #{owners_projects.inspect}")
        CloudController.logger.debug("Owner's resources are #{self.owner.resources.inspect}")

        owners_projects.each do |selected_project|
          CloudController.logger.debug("Found project #{selected_project.inspect}")
          if(selected_project.name == @project)
            CloudController.logger.debug("Looking for #{authenticated_user} in #{selected_project.inspect}")
            roles = selected_project.roles
            CloudController.logger.debug("Roles in #{selected_project.name} are #{roles}")
            if(!roles.nil?)
              roles.each do |role|
                CloudController.logger.debug("Searching role #{role.inspect} in #{selected_project.name}")
                if(!role.metadata_json.nil?)
                  metadata_hash = Yajl::Parser.parse(role.metadata_json, :symbolize_keys => true)
                  CloudController.logger.debug("Metadata hash for role is #{metadata_hash}")
                  CloudController.logger.debug("Users are #{metadata_hash[:users].inspect}")
                  users = metadata_hash[:users]
                  if(!users.nil? && !users.index(@authenticated_user).nil?) #User belongs to this role
                    CloudController.logger.debug("user #{@authenticated_user} is part of role #{role.name}")
                    #Get the resource permission for this role
                    acls = metadata_hash[:acls]
                    if(!acls.nil?)
                      CloudController.logger.debug("acls are #{acls.inspect}")
                      resource_permission_set = acls[self.owner.immutable_id.to_sym]
                      CloudController.logger.debug("permission set for #{self.owner.immutable_id} is #{resource_permission_set}")
                      if(!resource_permission_set.nil?)
                        permission_set_for_user.insert(0, resource_permission_set)
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end

      permission_set_for_user = permission_set_for_user.flatten()
      CloudController.logger.debug("final permission set for user #{@authenticated_user.inspect} is #{permission_set_for_user.inspect}")

      if(permission_set_for_user.index(:UPDATE.to_s).nil?)
        raise CloudError.new(CloudError::FORBIDDEN)
      end

    else
      CloudController.logger.debug("Org being created. Need to validate admin rights here")
      #TODO: Org being created. Need to validate admin rights here
    end

  end
  #Because the type column collides with the one used by ruby
  set_inheritance_column :ruby_type

  def set_immutable_id

    self.immutable_id = SecureRandom.uuid
    CloudController.logger.debug("Immutable id for resource #{self.name} is #{self.immutable_id}")

  end


end
