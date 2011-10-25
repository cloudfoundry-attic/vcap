
class Role < Resource

  before_create :set_type_to_role

  def set_type_to_role

    self.type = :role

  end

  def has_user(user_id)

    CloudController.logger.debug("metadata_json for role #{self.name} is #{self.metadata_json}")

    if(!self.metadata_json.nil?)

      metadata = Yajl::Parser.parse(self.metadata_json, :symbolize_keys => true)
      if(!metadata[:users].nil? && !metadata[:users].index(user_id).nil?) #Uses a linear search. need to search for a better solution
        CloudController.logger.debug("role #{self.name} already has user #{user_id}")
        true
      end

    else
      CloudController.logger.debug("nil metadata")
    end

    false

  end

  def add_user(user_id)

    if(!has_user(user_id))

      if(!self.metadata_json.nil?)

        metadata = Yajl::Parser.parse(self.metadata_json, :symbolize_keys => true)
        user_array = metadata[:users]
        if(user_array.nil?)
          user_array = [user_id]
        else
          user_array.insert(0, user_id)
        end

        metadata[:users] = user_array

      else
        metadata = { :users => [user_id] }.to_json
      end

      self.metadata_json = metadata.to_json

      CloudController.logger.debug("added user #{user_id} to role #{self.name}")

    end
  end

  #returns array of permissions for that resource. nil for no permissions
  def get_acl(resource_id)

    CloudController.logger.debug("metadata_json for role #{self.name} is #{self.metadata_json}")

    if(!self.metadata_json.nil?)

      metadata = Yajl::Parser.parse(self.metadata_json, :symbolize_keys => true)

      if(!metadata[:acls].nil? && !metadata[:acls][resource_id].nil?) #Uses a linear search. need to search for a better solution
        CloudController.logger.debug("role #{self.name} already has acl for resource #{resource_id}")
        metadata[:acls][resource_id]
      end
    else
      CloudController.logger.debug("nil metadata")
    end

    nil

  end

  # permission_array e.g. ["READ", "UPDATE"]
  def update_acl(resource_id, permission_array)

    CloudController.logger.debug("metadata_json for role #{self.name} is #{self.metadata_json}")
    CloudController.logger.debug("adding acl #{resource_id} => #{permission_array}")

    if(!self.metadata_json.nil?)

      metadata = Yajl::Parser.parse(self.metadata_json, :symbolize_keys => true)

      if(metadata[:acls].nil?)
        new_acl = {resource_id => permission_array}
        metadata.store(:acls, new_acl)
      else
        metadata[:acls].store(resource_id, permission_array)
      end

    else
      metadata = { :acls => {resource_id => permission_array}}.to_json

    end

    self.metadata_json = metadata.to_json

    CloudController.logger.debug("added permission #{permission_array} for resource #{resource_id} to role #{self.name}")

  end

end
