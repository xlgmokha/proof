# frozen_string_literal: true

# authorizations.id is a uuid, but tokens.authorization_id was created as a
# bigint, so the association could never match reliably.
class ChangeTokensAuthorizationIdToUuid < ActiveRecord::Migration[8.1]
  def up
    remove_index :tokens, :authorization_id
    remove_column :tokens, :authorization_id
    add_column :tokens, :authorization_id, :uuid
    add_index :tokens, :authorization_id
  end

  def down
    remove_index :tokens, :authorization_id
    remove_column :tokens, :authorization_id
    add_column :tokens, :authorization_id, :bigint
    add_index :tokens, :authorization_id
  end
end
