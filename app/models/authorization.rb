# frozen_string_literal: true

class Authorization < ApplicationRecord
  has_secure_token :code
  belongs_to :user
  belongs_to :client

  after_initialize do
    self.expired_at = 10.minutes.from_now unless expired_at.present?
  end
end
