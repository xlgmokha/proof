# frozen_string_literal: true

class Client < ApplicationRecord
  RESPONSE_TYPES = %w[code token].freeze
  audited
  has_secure_password
  has_many :authorizations
  attribute :redirect_uris, :string, array: true
  enum token_endpoint_auth_method: {
    client_secret_none: 0,
    client_secret_post: 1,
    client_secret_basic: 2
  }

  validates :redirect_uris, presence: true
  validates :jwks_uri, format: { with: URI_REGEX }, allow_blank: true
  validates :logo_uri, format: { with: URI_REGEX }, allow_blank: true
  validates :name, presence: true
  validates_each :redirect_uris do |record, _attr, value|
    invalid_uri = Array(value).find { |x| !x.match?(URI_REGEX) }
    record.errors[:redirect_uris] << 'is invalid.' if invalid_uri
  end

  after_initialize do
    self.password = SecureRandom.base58(24) unless password_digest
  end

  def grant_types
    [
      :authorization_code,
      :refresh_token,
      :client_credentials,
      :password,
      'urn:ietf:params:oauth:grant-type:saml2-bearer'
    ]
  end

  def access_token
    transaction do
      Token
        .active.where(subject: self, audience: self)
        .update_all(revoked_at: Time.now)
      Token.create!(subject: self, audience: self, token_type: :access)
    end
  end

  def valid_redirect_uri?(redirect_uri)
    redirect_uris.include? redirect_uri
  end

  def valid_response_type?(response_type)
    RESPONSE_TYPES.include?(response_type)
  end

  def redirect_url_for(user, oauth)
    sha256 = oauth[:code_challenge_method] == 'S256'
    authorization = authorizations.create!(
      user: user,
      challenge: oauth[:code_challenge],
      challenge_method: sha256 ? :sha256 : :plain
    )

    if oauth[:response_type] == 'code'
      redirect_url(code: authorization.code, state: oauth[:state])
    elsif oauth[:response_type] == 'token'
      access_token, = authorization.issue_tokens_to(
        self, token_types: [:access]
      )
      redirect_url(
        access_token: access_token.to_jwt,
        token_type: 'Bearer',
        expires_in: 5.minutes.to_i,
        scope: :admin,
        state: oauth[:state]
      )
    else
      redirect_url(error: 'unsupported_response_type', state: state)
    end
  end

  def redirect_url(fragments = {})
    URI.parse(
      "#{redirect_uris[0]}#" + fragments.map do |(key, value)|
        "#{key}=#{value}" if value.present?
      end.compact.join("&")
    ).to_s
  end
end
