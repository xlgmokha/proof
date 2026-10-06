# frozen_string_literal: true

module Oauth
  # RFC 9728: tells clients which authorization server protects a resource, so
  # they can obtain a token for it.
  class ResourceMetadataController < ActionController::API
    # The protected resources of this server, relative to its base URL.
    RESOURCES = {
      '' => 'Proof',
      '/oauth/me' => 'User info',
      '/oauth/clients' => 'Client registration',
      '/scim/v2' => 'SCIM'
    }.freeze

    def show
      path = params[:path].to_s.presence && "/#{params[:path]}"
      name = RESOURCES[path.to_s]
      return head :not_found unless name

      response.headers['Cache-Control'] = 'public, max-age=3600'
      render json: {
        resource: "#{request.base_url}#{path}",
        authorization_servers: [Oauth::Issuer.identifier],
        jwks_uri: jwks_url,
        scopes_supported: Scopes::SUPPORTED,
        bearer_methods_supported: %w[header body],
        resource_signing_alg_values_supported: %w[RS256],
        resource_name: name,
        resource_documentation: documentation_url,
        dpop_signing_alg_values_supported: DpopProof::ALGORITHMS
      }
    end
  end
end
