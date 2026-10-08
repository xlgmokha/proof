# frozen_string_literal: true

# RFC 9396: authorization details on grants and tokens, and the types a
# client says it will use.
class AddAuthorizationDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :authorizations, :authorization_details, :jsonb
    add_column :tokens, :authorization_details, :jsonb
    add_column :clients, :authorization_details_types, :string, array: true, null: false, default: []
  end
end
