# frozen_string_literal: true

FactoryBot.define do
  factory :scim_user, class: 'SCIM::User' do
    schemas { ["urn:ietf:params:scim:schemas:core:2.0:User"] }
    userName { FFaker::Internet.email }
    locale { I18n.available_locales.sample.to_s }
    timezone { User::VALID_TIMEZONES.sample }
  end
end
