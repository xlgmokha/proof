# frozen_string_literal: true

module Oauth
  # RFC 9728: tells clients which authorization server protects a resource, so
  # they can obtain a token for it.
  class ResourceMetadataController < ActionController::API
    def show
      path = params[:path].to_s.presence && "/#{params[:path]}"
      name = Oauth::Issuer::RESOURCES[path.to_s]
      return head :not_found unless name

      response.headers['Cache-Control'] = 'public, max-age=3600'
      render json: {
        resource: "#{Oauth::Issuer.identifier}#{path}",
        authorization_servers: [Oauth::Issuer.identifier],
        scopes_supported: Scopes::SUPPORTED,
        bearer_methods_supported: path == '/oauth/me' ? %w[header body] : %w[header],
        resource_name: name,
        resource_documentation: documentation_url,
        dpop_signing_alg_values_supported: DpopProof::ALGORITHMS
      }
    end
  end
end
