# frozen_string_literal: true

# RFC 8693 Section 4.1: the actor of a delegated token, as the `act` claim.
class AddActorToTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :tokens, :act, :jsonb
  end
end
