# frozen_string_literal: true

class Client < ApplicationRecord
  audited
  has_secure_token :secret
  has_many :authorizations

  after_initialize do
    self.uuid = SecureRandom.uuid unless uuid
    self.secret = self.class.generate_unique_secure_token unless secret
  end

  def authenticate(provided_secret)
    return self if secret == provided_secret
  end

  def access_token
    transaction do
      Token
        .active.where(subject: self, audience: self)
        .update_all(revoked_at: Time.now)
      Token.create!(subject: self, audience: self, token_type: :access)
    end
  end

  def to_param
    uuid
  end

  def redirect_url_for(user, response_type, state)
    authorization = authorizations.create!(user: user)
    if response_type == 'code'
      redirect_url(code: authorization.code, state: state)
    elsif response_type == 'token'
      access_token, = authorization.issue_tokens_to(
        self, token_types: [:access]
      )
      redirect_url(
        access_token: access_token.to_jwt,
        token_type: 'Bearer',
        expires_in: 5.minutes.to_i,
        scope: :admin,
        state: state
      )
    else
      redirect_url(error: 'unsupported_response_type', state: state)
    end
  end

  def redirect_url(fragments = {})
    "#{redirect_uri}#" + fragments.map do |(key, value)|
      "#{key}=#{value}" if value.present?
    end.compact.join("&")
  end
end
