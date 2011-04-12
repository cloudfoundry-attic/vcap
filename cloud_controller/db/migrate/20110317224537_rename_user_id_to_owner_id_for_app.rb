class RenameUserIdToOwnerIdForApp < ActiveRecord::Migration
  def self.up
    rename_column :apps, :user_id, :owner_id
  end

  def self.down
  end
end
