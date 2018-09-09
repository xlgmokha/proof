# frozen_string_literal: true

class Authorization < ApplicationRecord
  has_secure_token :code
  belongs_to :user
  belongs_to :client

  after_initialize do
    self.expired_at = 10.minutes.from_now unless expired_at.present?
  end

  def revoke!
    raise 'already revoked' if revoked?
    update!(revoked_at: Time.now)
  end

  def revoked?
    revoked_at.present?
  end
end
