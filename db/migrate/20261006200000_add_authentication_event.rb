# frozen_string_literal: true

# RFC 9470 and RFC 9068 Section 2.2.1: how and when the user authenticated
# when a grant was approved, carried by the access tokens that come of it.
class AddAuthenticationEvent < ActiveRecord::Migration[8.1]
  def change
    add_column :authorizations, :acr, :string
    add_column :authorizations, :auth_time, :integer
    add_column :tokens, :acr, :string
    add_column :tokens, :auth_time, :integer
  end
end
