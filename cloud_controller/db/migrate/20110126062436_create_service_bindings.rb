class CreateServiceBindings < ActiveRecord::Migration
  def self.up
    create_table :service_bindings do |t|
      t.belongs_to :service_config
      t.belongs_to :app
      t.belongs_to :user
      t.belongs_to :binding_token

      t.string :name
      t.text   :configuration
      t.text   :credentials
      t.text   :binding_options

      t.timestamps
    end

    add_index :service_bindings, :binding_token_id
    add_index :service_bindings, :service_config_id
    add_index :service_bindings, :app_id
    add_index :service_bindings, :user_id
  end

  def self.down
    remove_index :service_bindings, :column => :app_id
    remove_index :service_bindings, :column => :service_config_id
    remove_index :service_bindings, :column => :user_id
    remove_index :service_bindings, :column => :binding_token_id

    drop_table :service_bindings
  end
end
