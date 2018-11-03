# frozen_string_literal: true

json.issuer root_url
json.authorization_endpoint oauth_authorizations_url
json.token_endpoint oauth_tokens_url
json.token_endpoint_auth_methods_supported [:client_secret_basic]
json.token_endpoint_auth_signing_alg_values_supported ['RS256']
json.userinfo_endpoint oauth_me_url
json.jwks_uri ''
json.registration_endpoint oauth_clients_url
json.scopes_supported []
json.response_types_supported Client::RESPONSE_TYPES
json.service_documentation root_url + 'doc'
json.ui_locales_supported I18n.available_locales
