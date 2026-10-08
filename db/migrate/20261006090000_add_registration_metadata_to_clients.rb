# frozen_string_literal: true

# Client metadata of RFC 7591 Section 2. Existing clients keep every grant type
# they could use before.
class AddRegistrationMetadataToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :grant_types, :text, array: true, null: false,
      default: %w[
        authorization_code refresh_token client_credentials
        urn:ietf:params:oauth:grant-type:saml2-bearer urn:ietf:params:oauth:grant-type:jwt-bearer
      ]
    add_column :clients, :response_types, :text, array: true, null: false, default: %w[code]
    add_column :clients, :scope, :string
    add_column :clients, :contacts, :text, array: true, null: false, default: []
    add_column :clients, :client_uri, :string
    add_column :clients, :tos_uri, :string
    add_column :clients, :policy_uri, :string
    add_column :clients, :software_id, :string
    add_column :clients, :software_version, :string
  end
end
