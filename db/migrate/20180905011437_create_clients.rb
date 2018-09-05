# frozen_string_literal: true

class CreateClients < ActiveRecord::Migration[5.2]
  def change
    create_table :clients do |t|
      t.string :uuid, null: false, index: true
      t.string :name, null: false
      t.string :secret, null: false
      t.string :redirect_uri, null: false
      t.timestamps null: false
    end
  end
end
