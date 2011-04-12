class RenameStagingStackToRuntime < ActiveRecord::Migration
  def self.up
    rename_column :apps, :staging_stack, :runtime
  end

  def self.down
    rename_column :apps, :runtime, :staging_stack
  end
end
