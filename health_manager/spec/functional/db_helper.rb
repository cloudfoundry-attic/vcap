class HMExpectedStateHelperDB

  def initialize options
    @options = options
  end

  def config
    {
      'adapter' => 'sqlite3',
      'database' =>  File.join(@options['run_dir'], 'test.sqlite3'),
      'encoding' => 'utf8'
    }
  end

  def add_user(args)
    user = User.create(args)
    user.save!
    user
  end

  def find_user(args)
    User.where(args).first
  end

  def add_app(args)
    app = App.create(args)
    app.save!
    app
  end

  def make_app_with_owner_and_instance(app_def, user_def)
    app = App.new app_def
    owner = add_user user_def

    app.owner = owner
    app.instances = 1

    app.save!
    app
  end


  def find_app(args)
    App.where(args).first
  end

  def delete_all
    App.delete_all
    User.delete_all
  end


  def prepare_tests

    [App, User].each {|model| model.reset_column_information}

    ActiveRecord::Base.establish_connection config
    ActiveRecord::Migration.verbose = false

    ActiveRecord::Schema.define do

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
        t.text     "metadata"
        t.boolean  "external_secret",     :default => false
        t.datetime "created_at"
        t.datetime "updated_at"
        t.string   "staged_package_hash"
        t.integer  "file_descriptors",    :default => 256
        t.integer  "disk_quota",          :default => 2048
        t.integer  "lock_version",        :default => 0
        t.integer  "run_count",           :default => 0,         :null => false
      end

      create_table "users", :force => true do |t|
        t.string   "email"
        t.string   "crypted_password"
        t.boolean  "active",           :default => false
        t.datetime "created_at"
        t.datetime "updated_at"
      end

      add_index "users", ["email"], :name => "index_users_on_email"
    end
  end

  def release_resources
    delete_all
    ActiveRecord::Base.clear_all_connections!
  end
end
