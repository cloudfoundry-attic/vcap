class AddTimeoutToServices < ActiveRecord::Migration
  def self.up
    add_column :services, :timeout, :integer
  end

  def self.down
    remove_column :services, :timeout
  end
end
