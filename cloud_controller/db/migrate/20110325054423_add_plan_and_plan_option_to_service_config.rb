class AddPlanAndPlanOptionToServiceConfig < ActiveRecord::Migration
  def self.up
    add_column :service_configs, :plan, :string
    add_column :service_configs, :plan_option, :string
  end

  def self.down
    remove_column :service_configs, :plan
    remove_column :service_configs, :plan_option
  end
end
