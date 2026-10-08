# frozen_string_literal: true

# RFC 8628: a request, made by a device with limited input capabilities, that
# a user approves on another device.
class CreateDeviceAuthorizations < ActiveRecord::Migration[8.1]
  def change
    create_table :device_authorizations, id: :uuid do |t|
      t.references :client, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :device_code_digest, null: false
      t.string :user_code, null: false
      t.string :scope
      t.string :resource
      t.integer :status, null: false, default: 0
      t.integer :interval, null: false, default: 5
      t.datetime :last_polled_at
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :device_authorizations, :device_code_digest, unique: true
    add_index :device_authorizations, :user_code, unique: true
  end
end
