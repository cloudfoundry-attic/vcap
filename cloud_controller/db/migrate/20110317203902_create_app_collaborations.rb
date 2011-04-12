class CreateAppCollaborations < ActiveRecord::Migration
  def self.up
    create_table :app_collaborations do |t|
      t.belongs_to :app
      t.belongs_to :user

      t.timestamps
    end

    add_index :app_collaborations, [:app_id, :user_id], :unique => true
  end

  def self.down
    remove_index :app_collaborations, :column => [:app_id, :user_id]

    drop_table :app_collaborations
  end
end
