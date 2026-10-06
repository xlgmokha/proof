# frozen_string_literal: true

# RFC 9449 Section 10: an authorization code bound to the key of the client
# that will redeem it.
class AddDpopJktToAuthorizations < ActiveRecord::Migration[8.1]
  def change
    add_column :authorizations, :dpop_jkt, :string
  end
end
