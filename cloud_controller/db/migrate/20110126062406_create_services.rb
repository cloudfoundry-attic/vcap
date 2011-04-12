class CreateServices < ActiveRecord::Migration
  def self.up
    create_table :services do |t|
      # Required
      t.string :label
      t.string :url
      t.string :token

      # Parsed from label (where label = '<NAME>-<VERSION>')
      t.string :name
      t.string :version

      # Optional
      t.text   :description
      t.string :info_url
      t.text   :tags
      t.text   :plans
      t.text   :plan_options
      t.text   :binding_options
      t.text   :acls

      t.boolean :active, :default => true

      t.timestamps
    end

  end

  def self.down

    drop_table :services
  end
end
