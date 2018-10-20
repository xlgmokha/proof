# frozen_string_literal: true

FactoryBot.define do
  factory :client do
    name { FFaker::Name.name }
    redirect_uris { [FFaker::Internet.uri('https')] }
  end
end
