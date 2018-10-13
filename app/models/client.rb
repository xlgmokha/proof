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

  def redirect_uri_for(authorization, response_type, state)
    if response_type == 'code'
      redirect_uri_path(state: state) do |x|
        "#{x}?code=#{authorization.code}"
      end
    elsif response_type == 'token'
      access_token, = authorization.issue_tokens_to(
        self, token_types: [:access]
      )
      redirect_uri_path(state: state) do |x|
        x += "#access_token=#{access_token.to_jwt}"
        x += "&token_type=Bearer"
        x += "&expires_in=#{5.minutes.to_i}"
        x + "&scope=admin"
      end
    else
      error_uri(error: 'unsupported_response_type', state: state)
    end
  end

  def error_uri(state: nil, error: nil)
    redirect_uri_path(state: state) do |x|
      "#{x}#error=#{error}"
    end
  end

  private

  def redirect_uri_path(state: nil)
    x = yield redirect_uri
    state.present? ? "#{x}&state=#{state}" : x
  end
end
