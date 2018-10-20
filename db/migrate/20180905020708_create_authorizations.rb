# frozen_string_literal: true

class CreateAuthorizations < ActiveRecord::Migration[5.2]
  def change
    create_table :authorizations, id: :uuid do |t|
      t.references :user, foreign_key: true, type: :uuid
      t.references :client, foreign_key: true, type: :uuid
      t.string :code, null: false, index: true
      t.string :challenge
      t.integer :challenge_method, default: 0
      t.datetime :expired_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end
  end
end
