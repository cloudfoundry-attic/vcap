class AddCfPlanIdToService < ActiveRecord::Migration
  def self.up
    add_column :services, :cf_plan_id, :string
  end

  def self.down
    remove_column :services, :cf_plan_id
  end
end
