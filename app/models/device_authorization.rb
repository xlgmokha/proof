# frozen_string_literal: true

# RFC 8628: the device authorization grant.
class DeviceAuthorization < ApplicationRecord
  GRANT_TYPE = 'urn:ietf:params:oauth:grant-type:device_code'
  LIFETIME = 10.minutes
  INTERVAL = 5
  # Section 6.1: no vowels or look-alikes, so codes are easy to read out and
  # cannot spell words.
  USER_CODE_ALPHABET = 'BCDFGHJKLMNPQRSTVWXZ'
  USER_CODE_LENGTH = 8
  SLOW_DOWN_STEP = 5

  belongs_to :client
  belongs_to :user, optional: true
  enum :status, { pending: 0, approved: 1, denied: 2 }

  scope :unexpired, -> { where('expires_at > ?', Time.current) }

  # Creates a request and returns it with the device code, which is only known
  # now: it is stored hashed.
  def self.issue!(client, scope:, resource: nil)
    device_code = SecureRandom.urlsafe_base64(32)
    request = begin
      create!(
        client: client, scope: scope, resource: resource,
        device_code_digest: digest(device_code), user_code: generate_user_code,
        interval: INTERVAL, expires_at: LIFETIME.from_now
      )
    rescue ActiveRecord::RecordNotUnique
      retry
    end
    [request, device_code]
  end

  def self.find_by_device_code(device_code, client)
    return if device_code.blank?

    find_by(device_code_digest: digest(device_code.to_s), client_id: client.id)
  end

  # Tolerates the case, spaces and hyphens a person may type (Section 6.1).
  def self.find_pending_by_user_code(input)
    code = normalize(input)
    return if code.length != USER_CODE_LENGTH

    pending.unexpired.find_by(user_code: code)
  end

  def self.normalize(input)
    input.to_s.upcase.delete('^' + USER_CODE_ALPHABET)
  end

  def self.digest(device_code)
    Digest::SHA256.hexdigest(device_code)
  end

  def self.generate_user_code
    loop do
      code = Array.new(USER_CODE_LENGTH) { USER_CODE_ALPHABET[SecureRandom.random_number(USER_CODE_ALPHABET.length)] }.join
      return code unless exists?(user_code: code)
    end
  end

  def self.purge_expired!
    where(expires_at: ...1.day.ago).delete_all
  end

  # The code as shown to the user, XXXX-XXXX.
  def formatted_user_code
    user_code.scan(/.{1,4}/).join('-')
  end

  def expired?
    expires_at <= Time.current
  end

  def approve!(by)
    update!(status: :approved, user: by)
  end

  def deny!
    update!(status: :denied)
  end

  # Section 3.5: a device that polls faster than the interval is told to slow
  # down, and the interval grows.
  def polled_too_fast?
    last_polled_at.present? && last_polled_at > interval.seconds.ago
  end

  def record_poll!(slow_down: false)
    update!(last_polled_at: Time.current, interval: interval + (slow_down ? SLOW_DOWN_STEP : 0))
  end
end
