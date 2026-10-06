# frozen_string_literal: true

# A redeemed JWT bearer assertion, kept until it could no longer be accepted.
class UsedAssertion < ApplicationRecord
  belongs_to :client

  # Returns false when the assertion was already redeemed.
  def self.redeem!(client, jti, expires_at)
    where(expires_at: ...Time.current).delete_all
    create!(client: client, jti: jti, expires_at: expires_at)
    true
  rescue ActiveRecord::RecordNotUnique
    false
  end
end
