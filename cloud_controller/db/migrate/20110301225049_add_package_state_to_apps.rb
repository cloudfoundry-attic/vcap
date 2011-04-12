class AddPackageStateToApps < ActiveRecord::Migration
  def self.up
    add_column :apps, :package_state, :string
  end

  def self.down
    remove_column :apps, :package_state
  end
end
