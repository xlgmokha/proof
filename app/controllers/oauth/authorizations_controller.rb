# frozen_string_literal: true

module Oauth
  # RFC 6749 Section 3.1, the authorization code flow of Section 4.1, the PKCE
  # extension (RFC 7636), which this server requires of every client
  # (RFC 9700 Section 2.1.1), and requests that are signed (RFC 9101) or pushed
  # (RFC 9126).
  class AuthorizationsController < ApplicationController
    before_action :load_client, only: :show
    before_action :load_request, only: :show

    def show
      error = @authorization_request.error
      return redirect_with_error(*error) if error

      session[:oauth] = @authorization_request.parameters
      @details = AuthorizationDetails.parse(@authorization_request[:authorization_details], client: @client)
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
    def load_client
      @client = Client.find_by(id: params[:client_id])
      render plain: 'The client or its redirect_uri is not valid.', status: :bad_request unless @client
    end

    def load_request
      @authorization_request = AuthorizationRequest.load(@client, params.permit!, audiences: audiences)
      return if @authorization_request.redirect_uri

      render plain: 'The client or its redirect_uri is not valid.', status: :bad_request
    rescue AuthorizationRequest::Invalid => error
      # The request object or reference could not be used; the only redirect
      # that can be trusted is one the client sent and registered.
      @authorization_request = AuthorizationRequest.new(@client, params.permit(:redirect_uri, :state))
      return render plain: error.message, status: :bad_request unless @authorization_request.redirect_uri

      redirect_with_error(error.error, error.description)
    end

    def audiences
      [Oauth::Issuer.identifier, oauth_authorizations_url, root_url].uniq
    end

    def redirect_with_error(type, description = nil)
      redirect_to(
        @client.redirect_url(
          **authorization_error(type, @authorization_request[:state], description),
          to: @authorization_request[:redirect_uri].presence
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
