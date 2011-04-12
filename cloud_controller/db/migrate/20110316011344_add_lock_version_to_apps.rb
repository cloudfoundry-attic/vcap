class AddLockVersionToApps < ActiveRecord::Migration
  def self.up
    add_column :apps, :lock_version, :integer, :default => 0
  end

  def self.down
    remove_column :apps, :lock_version
  end
end
