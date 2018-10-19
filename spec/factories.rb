# frozen_string_literal: true

FactoryBot.define do
  sequence(:email) { |_n| FFaker::Internet.email }
  sequence(:password) { |_n| FFaker::Internet.password }
end
