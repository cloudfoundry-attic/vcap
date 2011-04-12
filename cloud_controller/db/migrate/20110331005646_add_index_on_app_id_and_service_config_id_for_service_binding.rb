class AddIndexOnAppIdAndServiceConfigIdForServiceBinding < ActiveRecord::Migration
  def self.up
    add_index :service_bindings, [:service_config_id, :app_id], :unique => true
  end

  def self.down
    remove_index :service_bindings, :column => [:service_config_id, :app_id]
  end
end
