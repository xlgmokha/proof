# frozen_string_literal: true

class UserSession < ApplicationRecord
  audited associated_with: :user, except: [:key, :accessed_at]
  belongs_to :user
  before_validation do |model|
    model.key = SecureRandom.urlsafe_base64(32)
  end

  scope :active, -> { where.not(id: revoked).where.not(id: expired) }
  scope :revoked, -> { where.not(revoked_at: nil) }
  scope :expired, -> { where(id: idle_timeout).or(where(id: absolute_timeout)) }
  scope :idle_timeout, -> { where("accessed_at < ?", 30.minutes.ago) }
  scope :absolute_timeout, -> { where('created_at < ?', 24.hours.ago) }

  def self.authenticate(key)
    return if key.blank?

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
    key
  end
end
