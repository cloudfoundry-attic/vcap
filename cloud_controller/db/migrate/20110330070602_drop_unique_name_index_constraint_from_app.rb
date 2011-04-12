class DropUniqueNameIndexConstraintFromApp < ActiveRecord::Migration
  def self.up
    remove_index "apps", "name"
    add_index "apps", ["name"], :name => "index_apps_on_name"
  end

  def self.down
    remove_index "apps", "name"
    add_index "apps", ["name"], :name => "index_apps_on_name", :unique => true
  end
end
