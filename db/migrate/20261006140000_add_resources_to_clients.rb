# frozen_string_literal: true

# RFC 8707 Section 2: the resources a client may ask tokens for, besides the
# ones this server protects itself. Set by the operator, not at registration.
class AddResourcesToClients < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :resources, :string, array: true, null: false, default: []
  end
end
