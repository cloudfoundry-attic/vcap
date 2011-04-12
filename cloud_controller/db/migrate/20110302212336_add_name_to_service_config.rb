class AddNameToServiceConfig < ActiveRecord::Migration
  def self.up
    add_column :service_configs, :name, :string
  end

  def self.down
    remove_column :service_configs, :name
  end
end
