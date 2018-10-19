# frozen_string_literal: true

FactoryBot.define do
  factory :authorization do
    user
    client
  end
end
