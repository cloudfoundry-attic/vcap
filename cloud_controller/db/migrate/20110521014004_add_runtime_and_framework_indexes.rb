class AddRuntimeAndFrameworkIndexes < ActiveRecord::Migration
  def self.up
    add_index "apps", "framework"
    add_index "apps", "runtime"
  end

  def self.down
    remove_index "apps", "framework"
    remove_index "apps", "runtime"
  end
end
