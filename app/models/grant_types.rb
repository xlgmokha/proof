# frozen_string_literal: true

# OAuth grant types accepted at the token endpoint.
module GrantTypes
  ALL = %w[
    authorization_code
    refresh_token
    client_credentials
    urn:ietf:params:oauth:grant-type:saml2-bearer
    urn:ietf:params:oauth:grant-type:jwt-bearer
  ].freeze
end
