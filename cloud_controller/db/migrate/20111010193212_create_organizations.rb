class CreateOrganizations < ActiveRecord::Migration
  def self.up
    create_table :organizations do |t|

      t.string :name, :null => false
      t.string :immutable_id, :null => false
      t.string :description
      t.string :status, :null => false, :default => "ACTIVE"

      t.timestamps

    end
    add_index :organizations, :immutable_id, :unique => true
    add_index :organizations, :name, :unique => true

  end

  def self.down
    remove_index :organizations, :column => :name
    remove_index :organizations, :column => :immutable_id

    drop_table :organizations
  end
end
