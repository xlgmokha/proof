# frozen_string_literal: true

# RFC 9126: authorization requests sent directly to the server, referenced
# later by a request_uri. Also the client metadata that makes pushing, or
# signing (RFC 9101), mandatory.
class CreatePushedAuthorizationRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :pushed_authorization_requests, id: :uuid do |t|
      t.references :client, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :reference, null: false
      t.jsonb :parameters, null: false, default: {}
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :pushed_authorization_requests, :reference, unique: true
    add_column :clients, :require_pushed_authorization_requests, :boolean, null: false, default: false
    add_column :clients, :require_signed_request_object, :boolean, null: false, default: false
  end
end
