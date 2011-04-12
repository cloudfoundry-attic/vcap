class AddMissingAppQuotas < ActiveRecord::Migration
  def self.up
    add_column :apps, :file_descriptors, :integer, :default => 256
    add_column :apps, :disk_quota, :integer, :default => 2048
    change_column :apps, :memory, :integer, :default => 256
  end

  def self.down
    change_column :apps, :memory, :integer, :default => 0
    remove_column :apps, :disk_quota
    remove_column :apps, :file_descriptors
  end
end
