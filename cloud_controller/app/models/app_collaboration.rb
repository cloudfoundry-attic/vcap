class AppCollaboration < ActiveRecord::Base
  belongs_to :app
  belongs_to :user

  validates_uniqueness_of :app_id, :scope => :user_id

  # TODO - When the last collaborator is destroyed, we should destroy the App.
end
