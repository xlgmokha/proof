# frozen_string_literal: true

module Oauth
  # RFC 9126 Section 2: the pushed authorization request endpoint.
  class PushedRequestsController < ActionController::API
    include ClientAuthentication
    before_action :apply_cache_headers
    before_action :authenticate_client!

    rescue_from GrantError, with: :render_oauth_error

    def create
      request = authorization_request
      raise GrantError.new('invalid_request', 'The redirect_uri is not valid.') unless request.redirect_uri

      error, description = request.error
      raise GrantError.new(error.to_s, description) if error

      pushed = current_client.pushed_authorization_requests.create!(parameters: request.parameters)
      render json: { request_uri: pushed.request_uri, expires_in: PushedAuthorizationRequest::LIFETIME.to_i }, status: :created
    end

    private

    def apply_cache_headers
      response.headers['Cache-Control'] = 'no-store'
      response.headers['Pragma'] = 'no-cache'
    end

    # The authenticated client must be the one the request is for.
    def authorization_request
      if params[:client_id].present? && params[:client_id] != current_client.to_param
        raise GrantError.new('invalid_request', 'client_id does not match the authenticated client.')
      end

      AuthorizationRequest.load(current_client, params.permit(*AuthorizationRequest::PARAMETERS, :request, :request_uri), audiences: assertion_audiences, pushing: true)
    rescue AuthorizationRequest::Invalid => error
      raise GrantError.new(error.error, error.description)
    end
  end
end
