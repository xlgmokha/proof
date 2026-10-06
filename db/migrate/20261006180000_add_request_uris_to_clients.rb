# frozen_string_literal: true

# RFC 9101 Section 10.5: the request object URLs a client has registered.
class AddRequestUrisToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :request_uris, :string, array: true, null: false, default: []
  end
end
