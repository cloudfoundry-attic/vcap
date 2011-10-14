
class Organization < ActiveRecord::Base

  #Found something other than a-zA-Z0-9 in the org name
  ORG_NAME_REGEX = /^[a-zA-Z0-9]/

  validates_format_of :name, :with => ORG_NAME_REGEX
  validates_uniqueness_of :name

  after_initialize :set_immutable_id

  def set_immutable_id

    self.immutable_id = SecureRandom.uuid
    CloudController.logger.debug("Immutable id for org #{self.name} is #{self.immutable_id}")

  end


end
