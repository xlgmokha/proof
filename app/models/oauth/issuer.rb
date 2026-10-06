# frozen_string_literal: true

module Oauth
  # The issuer identifier (RFC 8414 Section 2). The same value is used as the
  # `iss` of tokens, in authorization responses (RFC 9207) and in the server
  # metadata, as those must all agree.
  module Issuer
    module_function

    def identifier
      Saml::Kit.configuration.entity_id
    end
  end
end
