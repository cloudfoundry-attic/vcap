class CreateServiceConfigs < ActiveRecord::Migration
  def self.up
    create_table :service_configs do |t|
      t.belongs_to :service
      t.belongs_to :user

      t.string :alias        # The 'shortname' given by the user
      t.text   :data
      t.text   :credentials  # Special credentials given to the provisioner only

      t.timestamps
    end

    add_index :service_configs, :service_id
    add_index :service_configs, :user_id
    add_index :service_configs, [:user_id, :alias], :unique => true
  end

  def self.down
    remove_index :service_configs, :column => :user_id
    remove_index :service_configs, :column => :service_id
    remove_index :service_configs, :column => [:user_id, :alias]

    drop_table :service_configs
  end
end
