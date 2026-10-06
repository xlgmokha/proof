# frozen_string_literal: true

module Oauth
  # The issuer identifier (RFC 8414 Section 2). The same value is used as the
  # `iss` of tokens, in authorization responses (RFC 9207) and in the server
  # metadata, as those must all agree.
  module Issuer
    module_function

    # The protected resources of this server, relative to its identifier
    # (RFC 9728), and the audience a token carries when none was requested.
    RESOURCES = {
      '' => 'Proof',
      '/oauth/me' => 'User info',
      '/oauth/clients' => 'Client registration',
      '/scim/v2' => 'SCIM'
    }.freeze

    def identifier
      Saml::Kit.configuration.entity_id
    end

    # RFC 8414 Section 2: an https URL with no query or fragment component.
    # Plain http is only tolerated outside production.
    def valid?(value = identifier)
      uri = URI.parse(value.to_s)
      schemes = Rails.env.production? ? %w[https] : %w[https http]
      schemes.include?(uri.scheme) && uri.host.present? && uri.query.nil? && uri.fragment.nil? && !value.to_s.end_with?('?', '#')
    rescue URI::InvalidURIError
      false
    end

    # RFC 9068 Section 4: a resource server only accepts tokens whose audience
    # names it.
    def resource?(value)
      RESOURCES.keys.any? { |path| value.to_s == "#{identifier}#{path}" }
    end
  end
end
