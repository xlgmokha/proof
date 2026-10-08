# frozen_string_literal: true

FactoryBot.define do
  factory :authorization do
    user
    client
    # RFC 7636 Appendix B
    challenge { 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM' }
    challenge_method { :sha256 }
    scope { 'admin' }
  end
end
