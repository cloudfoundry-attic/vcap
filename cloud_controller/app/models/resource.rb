
class Resource < ActiveRecord::Base
  belongs_to :organization, :class_name => 'Organization'

  after_initialize :set_immutable_id

  def set_immutable_id

    self.immutable_id = SecureRandom.uuid
    CloudController.logger.debug("Immutable id created is #{self.immutable_id}")

  end

end
