# frozen_string_literal: true

FactoryBot.define do
  factory :client do
    uuid { SecureRandom.uuid }
    name { FFaker::Name.name }
    redirect_uri { FFaker::Internet.uri('https') }
  end
end
