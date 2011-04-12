class RenameStagingModelToFramework < ActiveRecord::Migration
  def self.up
    rename_column :apps, :staging_model, :framework
  end

  def self.down
    rename_column :apps, :framework, :staging_model
  end
end
