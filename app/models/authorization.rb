# frozen_string_literal: true

class Authorization < ApplicationRecord
  has_secure_token :code
  belongs_to :user
  belongs_to :client
  has_many :tokens

  scope :active, -> { where.not(id: revoked.or(where(id: expired))) }
  scope :revoked, -> { where('revoked_at < ?', Time.now) }
  scope :expired, -> { where('expired_at < ?', Time.now) }

  after_initialize do
    self.expired_at = 10.minutes.from_now unless expired_at.present?
  end

  def exchange
    transaction do
      revoke!
      [
        tokens.create!(subject: user, audience: client, token_type: :access),
        tokens.create!(subject: user, audience: client, token_type: :refresh),
      ]
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
