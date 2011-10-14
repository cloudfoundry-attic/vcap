class CreateResources < ActiveRecord::Migration
  def self.up
    create_table :resources do |t|

      t.string :immutable_id, :null => false
      t.belongs_to :organization, :null => false
      t.string :type
      t.text :metadata_hash

      t.timestamps
    end

    add_index :resources, :immutable_id, :unique => true
    add_index :resources, [:organization_id, :id], :unique => true
  end

  def self.down
    remove_index :resources, :column => [:organization_id, :id]
    remove_index :resources, :column => :immutable_id

    drop_table :resources
  end
end
