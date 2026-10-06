# frozen_string_literal: true

module Oauth
  class AuthorizationsController < ApplicationController
    VALID_RESPONSE_TYPES = %w[code token].freeze

    def show
      @client = Client.find(secure_params[:client_id])

      unless @client.valid_redirect_uri?(secure_params[:redirect_uri])
        state = secure_params[:state]
        type = :invalid_request
        return redirect_to error_url_for(@client, type, state)
      end

      unless @client.valid_response_type?(secure_params[:response_type])
        state = secure_params[:state]
        type = :unsupported_response_type
        return redirect_to error_url_for(@client, type, state)
      end

      return redirect_to error_url_for(@client, :invalid_request, secure_params[:state]) unless valid_code_challenge?

      session[:oauth] = secure_params.to_h
    end

    def create(oauth = session[:oauth])
      return render_error(:bad_request) if oauth.nil?

      client = Client.find(oauth[:client_id])
      redirect_to redirect_url_for(client, oauth)
    rescue StandardError => error
      logger.error(error)
      url = error_url_for(client, :invalid_request)
      redirect_to url if url
    end

    private

    # RFC 7636 Section 4.3: the method is only meaningful with a challenge, and
    # only plain and S256 are defined.
    def valid_code_challenge?
      method = secure_params[:code_challenge_method]
      return true if method.blank?

      %w[plain S256].include?(method) && secure_params[:code_challenge].present?
    end

    def secure_params
      params.permit(
        :client_id, :response_type, :redirect_uri,
        :state, :code_challenge, :code_challenge_method
      )
    end

    def redirect_url_for(client, oauth)
      client.redirect_url_for(current_user, oauth)
    end

    def error_url_for(client, type, state = nil)
      client&.redirect_url(error: type, state: state)
    end
  end
end
