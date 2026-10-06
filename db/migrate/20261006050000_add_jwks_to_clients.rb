# frozen_string_literal: true

# RFC 7591 Section 2: a client may register its public keys by value.
class AddJwksToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :jwks, :jsonb
  end
end
