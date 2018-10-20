# frozen_string_literal: true

class ChangeClients < ActiveRecord::Migration[5.2]
  def change
    add_column :clients, :redirect_uris, :text, array: true, default: [], null: false
    add_column :clients, :token_endpoint_auth_method, :integer, default: 0, null: false
    add_column :clients, :logo_uri, :string
    add_column :clients, :jwks_uri, :string
    remove_column :clients, :redirect_uri
  end
end
