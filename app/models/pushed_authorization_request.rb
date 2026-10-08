# frozen_string_literal: true

# RFC 9126: an authorization request pushed to the server. It is referenced by
# a request_uri and can be used once.
class PushedAuthorizationRequest < ApplicationRecord
  URN = 'urn:ietf:params:oauth:request_uri:'
  LIFETIME = 60.seconds

  belongs_to :client

  before_validation do
    self.reference ||= SecureRandom.urlsafe_base64(32)
    self.expires_at ||= LIFETIME.from_now
  end

  def request_uri
    "#{URN}#{reference}"
  end

  class << self
    # Looks the request up and removes it, so a request_uri cannot be replayed
    # (RFC 9126 Section 4). Returns nil when it is unknown, expired or was
    # pushed by another client.
    def consume(request_uri, client)
      return unless request_uri.to_s.start_with?(URN)

      transaction do
        found = lock.find_by(reference: request_uri.delete_prefix(URN), client_id: client.id)
        next if found.nil?

        found.destroy!
        found unless found.expires_at <= Time.current
      end
    end

    def purge_expired!
      where(expires_at: ...Time.current).delete_all
    end
  end
end
