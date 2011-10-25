
class Project < Resource
  has_many :roles, :class_name => "Role", :finder_sql => 'select roles.* from resources as roles, ' +
                                                         'resources as project where roles.owner_id = project.id ' +
                                                         'and roles.type = \'role\' and project.id = #{id}'

  before_create :set_type_to_project

  def set_type_to_project

    self.type = :project

  end

end
