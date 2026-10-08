# frozen_string_literal: true

# A redeemed JWT bearer assertion, kept until it could no longer be accepted.
class UsedAssertion < ApplicationRecord
  belongs_to :client

  # Returns false when the assertion was already redeemed.
  #
  # The insert is a single statement that skips a duplicate instead of raising,
  # so it is safe inside an enclosing transaction (on PostgreSQL a unique
  # violation would otherwise abort it) and safe against concurrent redemptions.
  def self.redeem!(client, jti, expires_at)
    # A record for this jti that already expired no longer blocks it.
    where(client_id: client.id, jti: jti, expires_at: ...Time.current).delete_all
    insert_all([{ client_id: client.id, jti: jti, expires_at: expires_at }], unique_by: %i[client_id jti]).rows.any?
  end

  # Housekeeping, run periodically (rake oauth:purge) rather than per request.
  def self.purge_expired!
    where(expires_at: ...Time.current).delete_all
  end
end
