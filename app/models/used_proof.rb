# frozen_string_literal: true

# A single-use value (such as the jti of a DPoP proof) that was seen already.
class UsedProof < ApplicationRecord
  # Returns false when the value was seen before and has not yet expired.
  def self.redeem!(*parts, expires_at:)
    digest = Digest::SHA256.hexdigest(parts.join("\0"))
    where(digest: digest, expires_at: ...Time.current).delete_all
    insert_all([{ digest: digest, expires_at: expires_at }], unique_by: :digest).rows.any?
  end

  def self.purge_expired!
    where(expires_at: ...Time.current).delete_all
  end
end
