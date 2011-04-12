class CorrectAppColumns < ActiveRecord::Migration
  def self.rebuild_apps
    drop_table :apps

    create_table "apps", :force => true do |t|
      t.integer  "user_id"
      t.string   "name"
      t.string   "staging_model"
      t.string   "staging_stack"
      t.integer  "memory", :default => 0
      t.integer  "instances", :default => 0
      t.string   "state", :default => 'STOPPED'
      t.string   "package_state", :default => 'PENDING'
      t.string   "package_hash"
      t.text     "environment_json"
      t.text     "metadata_json"
      t.boolean  "external_secret",  :default => false
      t.datetime "created_at"
      t.datetime "updated_at"
    end
    add_index "apps", ["user_id"], :name => "index_apps_on_user_id"
    add_index "apps", ["name"], :name => "index_apps_on_name", :unique => true
    add_index "apps", ["package_hash"], :name => "index_apps_on_package_hash"
  end

  def self.up
    rebuild_apps
  end

  def self.down
    rebuild_apps
  end
end
