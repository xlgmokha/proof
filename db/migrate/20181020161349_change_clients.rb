# frozen_string_literal: true

class ChangeClients < ActiveRecord::Migration[5.2]
  def change
    change_table :clients, bulk: true do |t|
      t.column :redirect_uris, :text, array: true, default: [], null: false
      t.column :token_endpoint_auth_method, :integer, default: 0, null: false
      t.column :logo_uri, :string
      t.column :jwks_uri, :string
    end
    remove_column :clients, :redirect_uri, :string
  end
end
