# frozen_string_literal: true

class UserSession < ApplicationRecord
  IDLE_TIMEOUT = 30.minutes
  audited associated_with: :user, except: [:key, :accessed_at]
  has_secure_token :key
  belongs_to :user

  scope :active, -> { where.not(id: revoked).where.not(id: expired) }
  scope :revoked, -> { where.not(revoked_at: nil) }
  scope :expired, -> { where(id: idle_timeout).or(where(id: absolute_timeout)) }
  scope :idle_timeout, -> { where("accessed_at < ?", IDLE_TIMEOUT.ago) }
  scope :absolute_timeout, -> { where('created_at < ?', 24.hours.ago) }

  def self.authenticate(key)
    return if key.blank?

    active.find_by(key: key)
  end

  def browser
    @browser ||= ::Browser.new(user_agent, accept_language: "en-us")
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def sudo?
    sudo_enabled_at.present? && sudo_enabled_at > 1.hour.ago
  end

  def sudo!
    update!(sudo_enabled_at: Time.current)
  end

  def access(request)
    update(
      accessed_at: Time.current,
      ip: request.ip,
      user_agent: request.user_agent,
    )
    key
  end
end
