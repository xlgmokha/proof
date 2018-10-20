# frozen_string_literal: true

class InstallAudited < ActiveRecord::Migration[5.2]
  def self.up
    create_table :audits, id: :uuid do |t|
      t.column :auditable_id, :string
      t.column :auditable_type, :string
      t.column :associated_id, :string
      t.column :associated_type, :string
      t.column :user_id, :string
      t.column :user_type, :string
      t.column :username, :string
      t.column :action, :string
      t.column :audited_changes, :text
      t.column :version, :integer, default: 0
      t.column :comment, :string
      t.column :remote_address, :string
      t.column :request_uuid, :string
      t.column :created_at, :datetime
    end

    add_index :audits, [:auditable_type, :auditable_id, :version]
    add_index :audits, [:associated_type, :associated_id]
    add_index :audits, [:user_id, :user_type]
    add_index :audits, :request_uuid
    add_index :audits, :created_at
  end

  def self.down
    drop_table :audits
  end
end
