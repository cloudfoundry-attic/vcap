class AddEnvironmentToApps < ActiveRecord::Migration
  def self.up
    add_column :apps, :environment_json, :text
    add_column :apps, :metadata_json, :text
    add_column :apps, :external_secret, :boolean, :default => false
  end

  def self.down
    remove_column :apps, :metadata_json
    remove_column :apps, :environment_json
    remove_column :apps, :external_secret
  end
end
