class Token < ApplicationRecord
  enum token_type: { access: 0, refresh: 1 }
  belongs_to :subject, polymorphic: true
  belongs_to :audience, polymorphic: true

  scope :expired, ->{ where('expired_at < ?', Time.now) }
  scope :revoked, ->{ where('revoked_at < ?', Time.now) }

  after_initialize do |x|
    x.uuid = SecureRandom.uuid if x.uuid.nil?
    x.expired_at = 1.hour.from_now if x.expired_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.now)
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
