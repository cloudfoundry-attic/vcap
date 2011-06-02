# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110521014004) do

  create_table "app_collaborations", :force => true do |t|
    t.integer  "app_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "app_collaborations", ["app_id", "user_id"], :name => "index_app_collaborations_on_app_id_and_user_id", :unique => true

  create_table "apps", :force => true do |t|
    t.integer  "owner_id"
    t.string   "name"
    t.string   "framework"
    t.string   "runtime"
    t.integer  "memory",              :default => 256
    t.integer  "instances",           :default => 0
    t.string   "state",               :default => "STOPPED"
    t.string   "package_state",       :default => "PENDING"
    t.string   "package_hash"
    t.text     "environment_json"
    t.text     "metadata_json"
    t.boolean  "external_secret",     :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "staged_package_hash"
    t.integer  "file_descriptors",    :default => 256
    t.integer  "disk_quota",          :default => 2048
    t.integer  "lock_version",        :default => 0
    t.integer  "run_count",           :default => 0,         :null => false
  end

  add_index "apps", ["framework"], :name => "index_apps_on_framework"
  add_index "apps", ["name"], :name => "index_apps_on_name"
  add_index "apps", ["owner_id"], :name => "index_apps_on_user_id"
  add_index "apps", ["package_hash"], :name => "index_apps_on_package_hash"
  add_index "apps", ["runtime"], :name => "index_apps_on_runtime"
  add_index "apps", ["staged_package_hash"], :name => "index_apps_on_staged_package_hash"

  create_table "binding_tokens", :force => true do |t|
    t.integer  "service_config_id"
    t.string   "uuid"
    t.string   "label"
    t.text     "binding_options"
    t.boolean  "auto_generated",    :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "binding_tokens", ["service_config_id"], :name => "index_binding_tokens_on_service_config_id"
  add_index "binding_tokens", ["uuid"], :name => "index_binding_tokens_on_uuid", :unique => true

  create_table "routes", :force => true do |t|
    t.integer  "app_id"
    t.string   "url"
    t.boolean  "active",     :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "routes", ["app_id"], :name => "index_routes_on_app_id"
  add_index "routes", ["url"], :name => "index_routes_on_url"

  create_table "service_bindings", :force => true do |t|
    t.integer  "service_config_id"
    t.integer  "app_id"
    t.integer  "user_id"
    t.integer  "binding_token_id"
    t.string   "name"
    t.text     "configuration"
    t.text     "credentials"
    t.text     "binding_options"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "service_bindings", ["app_id"], :name => "index_service_bindings_on_app_id"
  add_index "service_bindings", ["binding_token_id"], :name => "index_service_bindings_on_binding_token_id"
  add_index "service_bindings", ["service_config_id", "app_id"], :name => "index_service_bindings_on_service_config_id_and_app_id", :unique => true
  add_index "service_bindings", ["service_config_id"], :name => "index_service_bindings_on_service_config_id"
  add_index "service_bindings", ["user_id"], :name => "index_service_bindings_on_user_id"

  create_table "service_configs", :force => true do |t|
    t.integer  "service_id"
    t.integer  "user_id"
    t.string   "alias"
    t.text     "data"
    t.text     "credentials"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
    t.string   "plan"
    t.string   "plan_option"
  end

  add_index "service_configs", ["service_id"], :name => "index_service_configs_on_service_id"
  add_index "service_configs", ["user_id", "alias"], :name => "index_service_configs_on_user_id_and_alias", :unique => true
  add_index "service_configs", ["user_id"], :name => "index_service_configs_on_user_id"

  create_table "services", :force => true do |t|
    t.string   "label"
    t.string   "url"
    t.string   "token"
    t.string   "name"
    t.string   "version"
    t.text     "description"
    t.string   "info_url"
    t.text     "tags"
    t.text     "plans"
    t.text     "plan_options"
    t.text     "binding_options"
    t.text     "acls"
    t.boolean  "active",          :default => true
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "services", ["name", "version"], :name => "index_services_on_name_and_version", :unique => true

  create_table "users", :force => true do |t|
    t.string   "email"
    t.string   "crypted_password"
    t.boolean  "active",           :default => false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], :name => "index_users_on_email"

end
