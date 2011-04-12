class RemoveUniquenessConstraintOnRoutes < ActiveRecord::Migration
  def self.up
    remove_index "routes", "url"
    add_index "routes", "url", :unique => false
  end

  def self.down
    remove_index "routes", "url"
    add_index "routes", "url", :unique => true
  end
end
