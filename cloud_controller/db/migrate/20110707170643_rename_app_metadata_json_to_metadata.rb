class RenameAppMetadataJsonToMetadata < ActiveRecord::Migration
  def self.up
    rename_column :apps, :metadata_json, :metadata
  end

  def self.down
    rename_column :apps, :metadata, :metadata_json
  end
end
