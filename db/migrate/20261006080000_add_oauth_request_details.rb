# frozen_string_literal: true

# Details of the authorization request that later requests must be consistent
# with: RFC 6749 Sections 3.3 and 4.1.3, RFC 8707 and RFC 9449. The family ties
# a refresh token chain together so a replayed token can revoke all of it
# (RFC 9700 Section 4.14).
class AddOauthRequestDetails < ActiveRecord::Migration[8.1]
  def change
    add_column :authorizations, :redirect_uri, :string
    add_column :authorizations, :scope, :string
    add_column :authorizations, :resource, :string
    add_column :tokens, :scope, :string
    add_column :tokens, :resource, :string
    add_column :tokens, :dpop_jkt, :string
    add_column :tokens, :family_id, :uuid
    add_index :tokens, :family_id
  end
end
