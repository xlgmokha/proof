# frozen_string_literal: true

FactoryBot.define do
  factory :group do
    sequence(:display_name) { |n| "#{FFaker::Job.title} #{n}" }
  end
end
