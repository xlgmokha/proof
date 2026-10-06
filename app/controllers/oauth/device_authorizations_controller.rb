# frozen_string_literal: true

module Oauth
  # RFC 8628 Section 3.1: the device authorization endpoint.
  class DeviceAuthorizationsController < ActionController::API
    include ClientAuthentication
    before_action :apply_cache_headers
    before_action :authenticate_client!

    rescue_from GrantError, with: :render_oauth_error

    def create
      raise GrantError.new('unauthorized_client') unless current_client.grant_type?(DeviceAuthorization::GRANT_TYPE)

      scope = Scopes.resolve(params[:scope], allowed: current_client.allowed_scopes)
      raise GrantError.new('invalid_scope') unless scope

      request, device_code = DeviceAuthorization.issue!(current_client, scope: Scopes.format(scope))
      verification_uri = oauth_device_url
      render json: {
        device_code: device_code,
        user_code: request.formatted_user_code,
        verification_uri: verification_uri,
        verification_uri_complete: "#{verification_uri}?#{{ user_code: request.formatted_user_code }.to_query}",
        expires_in: DeviceAuthorization::LIFETIME.to_i,
        interval: request.interval
      }
    end

    private

    def apply_cache_headers
      response.headers['Cache-Control'] = 'no-store'
      response.headers['Pragma'] = 'no-cache'
    end
  end
end
