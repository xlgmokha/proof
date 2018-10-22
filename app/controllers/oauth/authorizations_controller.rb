# frozen_string_literal: true

module Oauth
  class AuthorizationsController < ApplicationController
    VALID_RESPONSE_TYPES = %w[code token].freeze

    def show
      @client = Client.find(secure_params[:client_id])

      unless @client.valid_redirect_uri?(secure_params[:redirect_uri])
        return redirect_to error_url_for(@client, :invalid_request)
      end

      unless @client.valid_response_type?(secure_params[:response_type])
        return redirect_to error_url_for(@client, :unsupported_response_type)
      end

      session[:oauth] = secure_params.to_h
    end

    def create(oauth = session[:oauth])
      return render_error(:bad_request) if oauth.nil?

      client = Client.find(oauth[:client_id])
      redirect_to client.redirect_url_for(current_user, oauth)
    rescue StandardError => error
      logger.error(error)
      redirect_to client.redirect_url(error: :invalid_request)
    end

    private

    def secure_params
      params.permit(
        :client_id, :response_type, :redirect_uri,
        :state, :code_challenge, :code_challenge_method
      )
    end

    def error_url_for(client, type)
      client.redirect_url(
        error: type,
        state: secure_params[:state]
      )
    end
  end
end
