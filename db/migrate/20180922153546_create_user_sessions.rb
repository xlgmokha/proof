# frozen_string_literal: true

class CreateUserSessions < ActiveRecord::Migration[5.2]
  def change
    create_table :user_sessions, id: :uuid do |t|
      t.references :user, foreign_key: true, type: :uuid
      t.string :key
      t.string :ip
      t.text :user_agent
      t.datetime :sudo_enabled_at
      t.datetime :accessed_at
      t.datetime :revoked_at

      t.timestamps
    end
    add_index :user_sessions, :key, unique: true
  end
end
