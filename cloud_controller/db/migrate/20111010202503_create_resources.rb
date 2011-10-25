class CreateResources < ActiveRecord::Migration
  def self.up
    create_table :resources do |t|

      t.string :name
      t.string :immutable_id, :null => false
      t.belongs_to :owner, :class_name => "Resource"
      t.string :name
      t.string :type
      t.text :metadata_json

      t.timestamps
    end

    add_index :resources, :immutable_id, :unique => true
    add_index :resources, :id, :unique => true
  end

  def self.down
    remove_index :resources, :column => :id
    remove_index :resources, :column => :immutable_id

    drop_table :resources
  end
end
