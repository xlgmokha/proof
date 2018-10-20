# frozen_string_literal: true

FactoryBot.define do
  factory :client do
    uuid { SecureRandom.uuid }
    name { FFaker::Name.name }
    redirect_uris { [FFaker::Internet.uri('https')] }
  end
end
