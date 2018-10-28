# frozen_string_literal: true

class Token < ApplicationRecord
  audited associated_with: :subject
  enum token_type: { access: 0, refresh: 1 }
  belongs_to :authorization, optional: true
  belongs_to :subject, polymorphic: true
  belongs_to :audience, polymorphic: true

  scope :active, -> { where.not(id: revoked.or(where(id: expired))) }
  scope :expired, -> { where('expired_at < ?', Time.now) }
  scope :revoked, -> { where('revoked_at < ?', Time.now) }

  after_initialize do |x|
    if x.expired_at.nil?
      x.expired_at = access? ? 1.hour.from_now : 1.day.from_now
    end
  end

  def issued_to?(audience)
    self.audience == audience
  end

  def revoke!
    update!(revoked_at: Time.now)
    authorization&.revoke!
  end

  def revoked?
    revoked_at.present?
  end

  def claims(custom_claims = {})
    {
      aud: audience.to_param,
      exp: expired_at.to_i,
      iat: created_at.to_i,
      iss: Saml::Kit.configuration.entity_id,
      jti: id,
      nbf: created_at.to_i,
      sub: subject.to_param,
      token_type: token_type,
    }.merge(custom_claims)
  end

  def to_jwt(custom_claims = {})
    @to_jwt ||= BearerToken.new.encode(claims(custom_claims))
  end

  def issue_tokens_to(client, token_types: [:access, :refresh])
    transaction do
      revoke!
      token_types.map do |x|
        Token.create!(subject: subject, audience: client, token_type: x)
      end
    end
  end

  class << self
    def revoked?(jti)
      revoked_token_identifiers[jti]
    end

    def revoked_token_identifiers
      Rails.cache.fetch("revoked-tokens", expires_in: 10.minutes) do
        Hash[Token.revoked.pluck(:id).map { |x| [x, true] }]
      end
    end

    def claims_for(token, token_type: :access)
      if token_type == :any
        claims = claims_for(token, token_type: :access)
        claims = claims_for(token, token_type: :refresh) if claims.empty?
        return claims
      end
      BearerToken.new.decode(token)
    end

    def authenticate(jwt)
      claims = claims_for(jwt, token_type: :access)
      return if claims.empty?

      token = Token.find(claims[:jti])
      return if token.refresh? || token.revoked?

      token
    end
  end
end
