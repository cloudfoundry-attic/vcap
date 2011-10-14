class AddCollabSpacesIdToApps < ActiveRecord::Migration
  def self.up
    add_column :apps, :collab_spaces_id, :string

  end

  def self.down
    remove_column :apps, :collab_spaces_id

  end
end
