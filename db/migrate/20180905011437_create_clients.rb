# frozen_string_literal: true

class CreateClients < ActiveRecord::Migration[5.2]
  def change
    create_table :clients, id: :uuid do |t|
      t.string :name, null: false
      t.string :password_digest, null: false
      t.string :redirect_uri, null: false
      t.timestamps null: false
    end
  end
end
