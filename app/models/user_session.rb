# frozen_string_literal: true

class UserSession < ApplicationRecord
  belongs_to :user
  before_validation :set_unique_key

  scope :active, -> { where("accessed_at > ?", 30.minutes.ago).where('created_at > ?', 24.hours.ago).where(revoked_at: nil) }

  def self.authenticate(key)
    active.find_by(key: key)
  end

  def revoke!
    update!(revoked_at: Time.now)
  end

  def sudo?
    sudo_enabled_at.present? && sudo_enabled_at > 1.hour.ago
  end

  def sudo!
    update!(sudo_enabled_at: Time.now)
  end

  def access(request)
    update(
      accessed_at: Time.now,
      ip: request.ip,
      user_agent: request.user_agent,
    )
  end

  private

  def set_unique_key
    self.key = SecureRandom.urlsafe_base64(32)
  end
end
