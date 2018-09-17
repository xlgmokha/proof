# frozen_string_literal: true

class Token < ApplicationRecord
  enum token_type: { access: 0, refresh: 1 }
  belongs_to :authorization, optional: true
  belongs_to :subject, polymorphic: true
  belongs_to :audience, polymorphic: true

  scope :active, -> { where.not(id: revoked.or(where(id: expired))) }
  scope :expired, -> { where('expired_at < ?', Time.now) }
  scope :revoked, -> { where('revoked_at < ?', Time.now) }

  after_initialize do |x|
    x.uuid = SecureRandom.uuid if x.uuid.nil?
    if x.expired_at.nil?
      x.expired_at = access? ? 1.hour.from_now : 1.day.from_now
    end
  end

  def revoke!
    update!(revoked_at: Time.now)
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
      jti: uuid,
      nbf: created_at.to_i,
      sub: subject.to_param,
      token_type: token_type,
    }.merge(custom_claims)
  end

  def to_jwt(custom_claims = {})
    @to_jwt ||= BearerToken.new.encode(claims(custom_claims))
  end

  def exchange
    transaction do
      revoke!
      [
        Token.create!(subject: subject, audience: audience, token_type: :access),
        Token.create!(subject: subject, audience: audience, token_type: :refresh),
      ]
    end
  end

  class << self
    def claims_for(token, token_type: :access)
      if token_type == :any
        claims = claims_for(token, token_type: :access)
        claims = claims_for(token, token_type: :refresh) if claims.empty?
        return claims
      end
      BearerToken.new.decode(token)
    end
  end
end
