# frozen_string_literal: true

class Authorization < ApplicationRecord
  has_secure_token :code
  belongs_to :user
  belongs_to :client
end
