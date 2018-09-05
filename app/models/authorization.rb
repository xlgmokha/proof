# frozen_string_literal: true

class Authorization < ApplicationRecord
  belongs_to :user
  belongs_to :client
end
