# frozen_string_literal: true

module Oauth
  # RFC 6749 Section 3.1, the authorization code flow of Section 4.1, the PKCE
  # extension (RFC 7636), which this server requires of every client
  # (RFC 9700 Section 2.1.1), and requests that are signed (RFC 9101) or pushed
  # (RFC 9126).
  class AuthorizationsController < ApplicationController
    before_action :reject_repeated_parameters, only: :show
    before_action :load_client, only: :show
    before_action :load_request, only: :show

    def show
      error = @authorization_request.error
      return redirect_with_error(*error) if error

      return unless authentication_satisfied?

      session[:oauth] = @authorization_request.parameters
      @scopes = Scopes.resolve(@authorization_request[:scope], allowed: @client.allowed_scopes) || []
      @details = AuthorizationDetails.parse(@authorization_request[:authorization_details], client: @client)
    end

    def create(oauth = session[:oauth])
      return render_error(:bad_request) if oauth.nil?

      client = Client.find(oauth[:client_id])
      session.delete(:oauth)
      return redirect_to denied_url_for(client, oauth), allow_other_host: true if params[:deny].present?

      redirect_to client.redirect_url_for(current_user, oauth, authentication: authentication_context.to_h), allow_other_host: true
    rescue StandardError => error
      logger.error(error)
      url = client&.redirect_url(**authorization_error('server_error', oauth[:state]), to: oauth[:redirect_uri].presence)
      return render_error(:bad_request) unless url

      redirect_to url, allow_other_host: true
    end

    private

    def authentication_context
      AuthenticationContext.for(Current.user_session, session[:mfa], current_user)
    end

    # RFC 9470 Section 4 and 5: `acr_values` that cannot be met fail the
    # request, and a login that is older than `max_age` is done again.
    def authentication_satisfied?
      context = authentication_context
      unless context.satisfies?(@authorization_request[:acr_values])
        redirect_with_error('unmet_authentication_requirements', 'The requested authentication context could not be met.')
        return false
      end
      # A login made in answer to the prompt is not asked for again.
      reauthenticated = session.delete(:reauthenticated_for) == request.fullpath
      return true unless context.older_than?(@authorization_request[:max_age]) && !reauthenticated

      reauthenticate!
      false
    end

    def reauthenticate!
      path = request.fullpath
      Current.user_session&.revoke!
      reset_session
      session[:return_to] = path
      session[:reauthenticated_for] = path
      redirect_to new_session_path
    end

    # RFC 6749 Section 4.1.2.1: when the client or redirect URI cannot be
    # trusted, the user is told and nothing is redirected.
    # RFC 6749 Section 3.1: no parameter more than once. The redirect_uri may be
    # one of them, so the answer is shown to the user rather than redirected.
    def reject_repeated_parameters
      keys = URI.decode_www_form(request.query_string.to_s).map(&:first).reject { |x| x.end_with?('[]') }
      return if keys.uniq.size == keys.size

      render plain: 'A parameter was repeated.', status: :bad_request
    rescue ArgumentError
      render plain: 'The request is malformed.', status: :bad_request
    end

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
      # RFC 9101 Section 4: the issuer identifier of the authorization server.
      [Oauth::Issuer.identifier]
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
      { error: type, error_description: description&.gsub(/[^\x20\x21\x23-\x5B\x5D-\x7E]/, ''), state: state, iss: Oauth::Issuer.identifier }
    end
  end
end
