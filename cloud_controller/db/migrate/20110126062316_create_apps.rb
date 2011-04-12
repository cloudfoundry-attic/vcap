class CreateApps < ActiveRecord::Migration
  def self.up
    create_table :apps do |t|
      t.belongs_to :user
      t.string :name
      t.string :staging_model
      t.string :staging_stack
      t.string :memory
      t.integer :instances
      t.string :state

      t.timestamps
    end

    add_index :apps, :user_id
  end

  def self.down
    remove_index :apps, :column => :user_id

    drop_table :apps
  end
end
