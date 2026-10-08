# frozen_string_literal: true

# Remembers the jti of redeemed JWT bearer assertions (RFC 7523 Section 3) so
# they cannot be replayed. A table, unlike a cache, is shared by every process.
class CreateUsedAssertions < ActiveRecord::Migration[8.1]
  def change
    create_table :used_assertions, id: :uuid do |t|
      t.references :client, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :jti, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :used_assertions, %i[client_id jti], unique: true
    add_index :used_assertions, :expires_at
  end
end
