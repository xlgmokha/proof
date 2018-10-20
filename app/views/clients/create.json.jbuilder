# frozen_string_literal: true

json.client_id @client.to_param
json.client_secret @client.password
json.client_id_issued_at @client.created_at.to_i
json.client_secret_expires_at 0
json.redirect_uris @client.redirect_uris
json.grant_types @client.grant_types
json.client_name @client.name
json.token_endpoint_auth_method @client.token_endpoint_auth_method
json.logo_uri @client.logo_uri
json.jwks_uri @client.jwks_uri
