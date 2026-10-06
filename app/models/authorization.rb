# frozen_string_literal: true

class Authorization < ApplicationRecord
  # RFC 7636 Section 4.1: 43 to 128 unreserved characters.
  PKCE_VERIFIER = /\A[A-Za-z0-9\-._~]{43,128}\z/
  audited associated_with: :user
  has_secure_token :code
  belongs_to :user
  belongs_to :client
  has_many :tokens, dependent: :delete_all
  enum :challenge_method, { plain: 0, sha256: 1 }

  scope :active, -> { where.not(id: revoked.or(where(id: expired))) }
  scope :revoked, -> { where('revoked_at < ?', Time.current) }
  scope :expired, -> { where('expired_at < ?', Time.current) }

  after_initialize do
    self.expired_at = 10.minutes.from_now if expired_at.blank?
  end

  def valid_verifier?(code_verifier)
    return true if challenge.blank?
    return false unless PKCE_VERIFIER.match?(code_verifier.to_s)

    ActiveSupport::SecurityUtils.secure_compare(
      challenge, transform_verifier(code_verifier)
    )
  end

  def scopes
    Scopes.parse(scope)
  end

  # Whether the authorization request included this redirect_uri (RFC 6749
  # Section 4.1.3: it must be repeated at the token endpoint if it was sent).
  def redirect_uri_matches?(value)
    redirect_uri.blank? || redirect_uri == value
  end

  def issue_tokens_to(client, token_types: [:access, :refresh], resource: self.resource, authorization_details: self.authorization_details)
    transaction do
      revoke!
      token_types.map do |x|
        tokens.create!(
          subject: user, audience: client, token_type: x,
          scope: scope, resource: resource, family_id: id, authorization_details: authorization_details,
          acr: acr, auth_time: auth_time
        )
      end
    end
  end

  # An authorization code may be used once. Revokes it and every token issued
  # from it, including those from refreshes (RFC 6749 Section 4.1.2).
  def revoke!
    raise 'already revoked' if revoked?

    now = Time.current
    update!(revoked_at: now)
    revoke_tokens!
  end

  def revoke_tokens!
    Token.where(family_id: id, revoked_at: nil).update_all(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  private

  # RFC 7636 Section 4.6
  def transform_verifier(code_verifier)
    return code_verifier unless sha256?

    Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
  end
end
