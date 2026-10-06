# frozen_string_literal: true

module Oauth
  # RFC 6749 Section 3.1, the authorization code flow of Section 4.1 and the
  # PKCE extension (RFC 7636), which this server requires of every client
  # (RFC 9700 Section 2.1.1).
  class AuthorizationsController < ApplicationController
    before_action :load_client_and_redirect_uri, only: :show

    def show
      return redirect_with_error(:unsupported_response_type) unless @client.valid_response_type?(secure_params[:response_type])

      error = pkce_error || scope_error
      return redirect_with_error(*error) if error

      session[:oauth] = secure_params.to_h
    end

    def create(oauth = session[:oauth])
      return render_error(:bad_request) if oauth.nil?

      client = Client.find(oauth[:client_id])
      session.delete(:oauth)
      return redirect_to denied_url_for(client, oauth), allow_other_host: true if params[:deny].present?

      redirect_to client.redirect_url_for(current_user, oauth), allow_other_host: true
    rescue StandardError => error
      logger.error(error)
      url = client&.redirect_url(**authorization_error('server_error', oauth[:state]), to: oauth[:redirect_uri].presence)
      return render_error(:bad_request) unless url

      redirect_to url, allow_other_host: true
    end

    private

    # RFC 6749 Section 4.1.2.1: when the client or redirect URI cannot be
    # trusted, the user is told and nothing is redirected.
    def load_client_and_redirect_uri
      @client = Client.find_by(id: secure_params[:client_id])
      @redirect_uri = @client&.resolve_redirect_uri(secure_params[:redirect_uri])
      return if @redirect_uri

      render plain: 'The client or its redirect_uri is not valid.', status: :bad_request
    end

    # RFC 7636 Section 4.3 (the method defaults to plain, which is not
    # accepted here).
    def pkce_error
      challenge = secure_params[:code_challenge]
      return [:invalid_request, 'code_challenge is required.'] if challenge.blank?
      return [:invalid_request, 'code_challenge_method must be S256.'] unless secure_params[:code_challenge_method] == 'S256'
      return if Authorization::PKCE_VERIFIER.match?(challenge)

      [:invalid_request, 'code_challenge is not valid.']
    end

    def scope_error
      [:invalid_scope, 'The requested scope is not supported.'] unless Scopes.resolve(secure_params[:scope])
    end

    def secure_params
      params.permit(
        :client_id, :response_type, :redirect_uri, :scope, :resource,
        :state, :code_challenge, :code_challenge_method
      )
    end

    def redirect_with_error(type, description = nil)
      redirect_to(
        @client.redirect_url(
          **authorization_error(type, secure_params[:state], description), to: secure_params[:redirect_uri].presence
        ),
        allow_other_host: true
      )
    end

    def denied_url_for(client, oauth)
      client.redirect_url(
        **authorization_error('access_denied', oauth[:state]), to: oauth[:redirect_uri].presence
      )
    end

    # RFC 6749 Section 4.1.2.1 and RFC 9207 (the issuer is always identified).
    def authorization_error(type, state, description = nil)
      { error: type, error_description: description, state: state, iss: Oauth::Issuer.identifier }
    end
  end
end
