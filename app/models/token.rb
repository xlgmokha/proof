# frozen_string_literal: true

class Token < ApplicationRecord
  ACCESS_TYP = 'at+jwt' # RFC 9068 Section 2.1
  REFRESH_TYP = 'rt+jwt'

  audited associated_with: :subject
  enum :token_type, { access: 0, refresh: 1 }
  belongs_to :authorization, optional: true
  belongs_to :subject, polymorphic: true
  belongs_to :audience, polymorphic: true

  scope :active, -> { where.not(id: revoked.or(where(id: expired))) }
  scope :expired, -> { where('expired_at < ?', Time.current) }
  scope :revoked, -> { where('revoked_at < ?', Time.current) }

  after_initialize do |x|
    if x.expired_at.nil?
      x.expired_at = access? ? 1.hour.from_now : 1.day.from_now
    end
  end

  before_create do
    self.family_id ||= authorization_id || SecureRandom.uuid
  end

  def issued_to?(audience)
    self.audience == audience
  end

  # Revokes this token. Revoking a refresh token also revokes the access tokens
  # of the same grant (RFC 7009 Section 2.1).
  def revoke!
    ActiveRecord::Base.transaction do
      update!(revoked_at: Time.current) unless revoked?
      revoke_family! if refresh?
    end
  end

  def revoke_family!
    Token.where(family_id: family_id, revoked_at: nil).update_all(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expired_at.present? && expired_at <= Time.current
  end

  def scopes
    Scopes.parse(scope)
  end

  def claims(custom_claims = {})
    {
      aud: resource.presence || audience.to_param,
      client_id: audience.to_param,
      exp: expired_at.to_i,
      iat: created_at.to_i,
      iss: Oauth::Issuer.identifier,
      jti: id,
      nbf: created_at.to_i,
      sub: subject.to_param,
      token_type: token_type,
    }.merge(scope.present? ? { scope: scope } : {})
      .merge(dpop_jkt.present? ? { cnf: { jkt: dpop_jkt } } : {})
      .merge(custom_claims)
  end

  def to_jwt(custom_claims = {})
    @to_jwt ||= BearerToken.new.encode(claims(custom_claims), typ: access? ? ACCESS_TYP : REFRESH_TYP)
  end

  def issue_tokens_to(client, token_types: [:access, :refresh], scope: self.scope, resource: self.resource)
    transaction do
      revoke!
      token_types.map do |x|
        Token.create!(
          subject: subject, audience: client, token_type: x, scope: scope,
          resource: resource, dpop_jkt: dpop_jkt, family_id: family_id
        )
      end
    end
  end

  class << self
    # A revoked token is rejected immediately; the database is the source of truth.
    def revoked?(jti)
      revoked.exists?(id: jti)
    end

    def claims_for(token, token_type: :access)
      if token_type == :any
        claims = claims_for(token, token_type: :access)
        claims = claims_for(token, token_type: :refresh) if claims.empty?
        return claims
      end
      typ = token_type == :refresh ? REFRESH_TYP : ACCESS_TYP
      claims = BearerToken.new.decode(token, typ: typ)
      claims[:token_type].to_s == token_type.to_s ? claims : {}
    end

    # The token record behind a JWT of the given type, if it is a token of this server.
    def from_jwt(jwt, token_type:)
      jti = claims_for(jwt, token_type: token_type)[:jti]
      jti.present? && jti.to_s.match?(ApplicationRecord::UUID) ? find_by(id: jti, token_type: token_type) : nil
    end

    # An access token that may still be used. Tokens bound to a DPoP key are
    # only accepted by callers that can check the proof (RFC 9449 Section 7).
    def authenticate(jwt, allow_bound: false)
      token = from_jwt(jwt, token_type: :access)
      return if token.nil? || token.revoked? || token.expired?
      return if token.dpop_jkt.present? && !allow_bound

      token
    end
  end
end
