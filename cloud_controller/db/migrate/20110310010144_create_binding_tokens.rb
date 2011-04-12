class CreateBindingTokens < ActiveRecord::Migration
  def self.up
    create_table :binding_tokens do |t|
      t.belongs_to :service_config

      t.string  :uuid
      t.string  :label
      t.text    :binding_options
      t.boolean :auto_generated, :default => false # Allows us to reap tokens when binding fails

      t.timestamps
    end

    add_index :binding_tokens, :service_config_id
    add_index :binding_tokens, :uuid, :unique => true
  end

  def self.down
    remove_index :binding_tokens, :column => :service_config_id
    remove_index :binding_tokens, :column => :uuid

    drop_table :binding_tokens
  end
end
