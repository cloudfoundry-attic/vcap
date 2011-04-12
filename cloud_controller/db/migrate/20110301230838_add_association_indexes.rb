class AddAssociationIndexes < ActiveRecord::Migration
  def self.up
    add_index :routes, :app_id
    add_index :routes, :url, :unique => true
    add_index :services, [:name, :version], :unique => true
    add_index :users, :email
  end

  def self.down
    remove_index :users, :column => :email
    remove_index :services, :column => [:name, :version]
    remove_index :routes, :column => :url
    remove_index :routes, :column => :app_id
  end
end
