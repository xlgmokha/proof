# frozen_string_literal: true

# A user code that was entered wrongly (RFC 8628 Section 5.1). Too many
# failures by one person, or by everyone, stop further guesses for a while.
class FailedDeviceAttempt < ApplicationRecord
  WINDOW = 15.minutes
  PER_SUBJECT = 5
  GLOBAL = 200

  def self.record!(subject)
    create!(subject: subject.to_s, created_at: Time.current)
  end

  def self.locked?(subject)
    recent = where('created_at > ?', WINDOW.ago)
    recent.where(subject: subject.to_s).count >= PER_SUBJECT || recent.count >= GLOBAL
  end

  def self.purge_expired!
    where('created_at <= ?', WINDOW.ago).delete_all
  end
end
