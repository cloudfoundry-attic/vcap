class AddStagedHashToApps < ActiveRecord::Migration
  def self.up
    add_column :apps, :staged_package_hash, :string
    add_index :apps, :staged_package_hash
  end

  def self.down
    remove_index :apps, :column => :staged_package_hash
    remove_column :apps, :staged_package_hash
  end
end
