
class Organization < Resource
  attr_accessor :authenticated_user
  attr_accessor :org
  attr_accessor :project

  has_many :resources, :class_name => "Resource", :finder_sql => 'select dependencies.* from resources as org, ' +
                                                                  'resources as dependencies where dependencies.owner_id = org.id ' +
                                                                  'and (dependencies.type != \'project\' or ' +
                                                                  'dependencies.type != \'organization\' or ' +
                                                                  'dependencies.type != \'role\') ' +
                                                                  'and org.id = #{id}'
  has_many :projects, :class_name => "Project", :finder_sql => 'select dependencies.* from resources as org, ' +
                                                                  'resources as dependencies where dependencies.owner_id = org.id ' +
                                                                  'and dependencies.type = \'project\' and org.id = #{id}'

  after_create :set_organization_to_self

  def set_organization_to_self

    self.owner_id = self.id
    self.save!
    CloudController.logger.debug("Organization saved is #{self.inspect}")

  end

  before_create :set_type_to_organization

  def set_type_to_organization

    self.type = :organization

  end


  #TODO: Need to implement a common delete for this stuff


end
