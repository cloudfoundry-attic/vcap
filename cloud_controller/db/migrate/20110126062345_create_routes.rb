class CreateRoutes < ActiveRecord::Migration
  def self.up
    create_table :routes do |t|
      t.belongs_to :app
      t.string :url
      t.boolean :active, :default => false

      t.timestamps
    end
  end

  def self.down
    drop_table :routes
  end
end
