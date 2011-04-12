class AddRunCountToApps < ActiveRecord::Migration
  def self.up
    add_column :apps, :run_count, :integer, :null => false, :default => 0
  end

  def self.down
    remove_column :apps, :run_count
  end
end
