# frozen_string_literal: true

# Backs the SCIM Group resource (RFC 7643 Section 4.2).
class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups, id: :uuid do |t|
      t.string :display_name, null: false
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :groups, 'lower(display_name)', unique: true, name: 'index_groups_on_lower_display_name'

    create_table :group_memberships, id: :uuid do |t|
      t.references :group, type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.timestamps
    end
    add_index :group_memberships, [:group_id, :user_id], unique: true
  end
end
