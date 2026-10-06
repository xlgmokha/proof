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

      pushed = current_client.pushed_authorization_requests.create!(parameters: request.parameters.merge(dpop_jkt: dpop_jkt_for(request).presence).compact)
      render json: { request_uri: pushed.request_uri, expires_in: PushedAuthorizationRequest::LIFETIME.to_i }, status: :created
    end

    private

    # RFC 9449 Section 10.1: a proof sent with the push binds the code to its key.
    def dpop_jkt_for(pushed_request)
      proof = request.headers['DPoP']
      return pushed_request[:dpop_jkt] if proof.blank?

      jkt = DpopProof.new(proof, method: 'POST', url: oauth_par_url, nonce_required: DpopNonce.required?).verify!
      raise GrantError.new('invalid_dpop_proof', 'dpop_jkt does not match the DPoP proof.') if pushed_request[:dpop_jkt].present? && pushed_request[:dpop_jkt] != jkt

      jkt
    rescue DpopProof::UseNonce => error
      response.headers['DPoP-Nonce'] = DpopNonce.current
      raise GrantError.new('use_dpop_nonce', error.message)
    rescue DpopProof::Invalid => error
      raise GrantError.new('invalid_dpop_proof', error.message)
    end

    def apply_cache_headers
      response.headers['Cache-Control'] = 'no-store'
      response.headers['Pragma'] = 'no-cache'
    end

    # The authenticated client must be the one the request is for.
    def authorization_request
      if params[:client_id].present? && params[:client_id] != current_client.to_param
        raise GrantError.new('invalid_request', 'client_id does not match the authenticated client.')
      end

      AuthorizationRequest.load(current_client, params.permit(*AuthorizationRequest::PARAMETERS, :request, :request_uri), audiences: [Oauth::Issuer.identifier], pushing: true)
    rescue AuthorizationRequest::Invalid => error
      raise GrantError.new(error.error, error.description)
    end
  end
end
