# frozen_string_literal: true

json.client_id @client.to_param
# The secret is only known when the client is registered; public clients have none.
json.client_secret @client.password if @client.password.present? && !@client.public_client?
json.client_id_issued_at @client.created_at.to_i
json.client_secret_expires_at 0
json.redirect_uris @client.redirect_uris
json.grant_types @client.grant_types
json.response_types @client.response_types
json.client_name @client.name
json.token_endpoint_auth_method @client.token_endpoint_auth_method.to_s == 'client_secret_none' ? 'none' : @client.token_endpoint_auth_method
json.scope @client.scope if @client.scope.present?
json.contacts @client.contacts if @client.contacts.present?
{
  logo_uri: @client.logo_uri, client_uri: @client.client_uri, tos_uri: @client.tos_uri,
  policy_uri: @client.policy_uri, software_id: @client.software_id,
  software_version: @client.software_version, jwks_uri: @client.jwks_uri
}.each { |name, value| json.set!(name, value) if value.present? }
json.jwks @client.jwks if @client.jwks.present?
json.authorization_details_types @client.authorization_details_types if @client.authorization_details_types.present?
json.request_uris @client.request_uris if @client.request_uris.present?
json.require_pushed_authorization_requests @client.require_pushed_authorization_requests
json.require_signed_request_object @client.require_signed_request_object
json.registration_client_uri oauth_client_url(@client)
json.registration_access_token @registration_access_token if @registration_access_token
