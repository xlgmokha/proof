# frozen_string_literal: true

class CreateTokens < ActiveRecord::Migration[5.2]
  def change
    create_table :tokens do |t|
      t.string :uuid, index: { unique: true }
      t.references :authorization
      t.references :subject, polymorphic: true
      t.references :audience, polymorphic: true
      t.integer :token_type, default: 0
      t.datetime :expired_at
      t.datetime :revoked_at

      t.timestamps
    end
  end
end
