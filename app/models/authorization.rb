# frozen_string_literal: true

class Authorization < ApplicationRecord
  audited associated_with: :user
  has_secure_token :code
  belongs_to :user
  belongs_to :client
  has_many :tokens
  enum challenge_method: { plain: 0, sha256: 1 }

  scope :active, -> { where.not(id: revoked.or(where(id: expired))) }
  scope :revoked, -> { where('revoked_at < ?', Time.now) }
  scope :expired, -> { where('expired_at < ?', Time.now) }

  after_initialize do
    self.expired_at = 10.minutes.from_now unless expired_at.present?
  end

  def valid_verifier?(code_verifier)
    return true unless challenge.present?

    challenge ==
      if sha256?
        Base64.urlsafe_encode64(Digest::SHA256.hexdigest(code_verifier))
      else
        code_verifier
      end
  end

  def issue_tokens_to(client, token_types: [:access, :refresh])
    transaction do
      revoke!
      token_types.map do |x|
        tokens.create!(subject: user, audience: client, token_type: x)
      end
    end
  end

  def revoke!
    raise 'already revoked' if revoked?

    update!(revoked_at: Time.now)
  end

  def revoked?
    revoked_at.present?
  end
end
