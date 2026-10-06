# frozen_string_literal: true

# Remembers DPoP proofs (RFC 9449 Section 11.1) and other single-use
# identifiers so they cannot be replayed within their validity window.
class CreateUsedProofs < ActiveRecord::Migration[8.1]
  def change
    create_table :used_proofs, id: :uuid do |t|
      t.string :digest, null: false
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :used_proofs, :digest, unique: true
    add_index :used_proofs, :expires_at
  end
end
