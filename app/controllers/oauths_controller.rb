# frozen_string_literal: true

class OauthsController < ApplicationController
  VALID_RESPONSE_TYPES = %w[code token].freeze

  def show
    @client = Client.find_by!(uuid: params[:client_id])

    if @client.redirect_uri != params[:redirect_uri]
      return redirect_to @client.redirect_uri_path(
        error: 'invalid_request',
        state: params[:state]
      )
    end

    unless VALID_RESPONSE_TYPES.include?(params[:response_type])
      return redirect_to @client.redirect_uri_path(
        error: 'unsupported_response_type',
        state: params[:state]
      )
    end

    session[:oauth] = {
      client_id: params[:client_id],
      response_type: params[:response_type],
      state: params[:state],
    }
  end

  def create
    return render_error(:not_found) if session[:oauth].nil?

    client = Client.find_by!(uuid: session[:oauth][:client_id])
    authorization = client.authorizations.create!(user: current_user)

    if session[:oauth][:response_type] == 'code'
      redirect_to client.redirect_uri_path(
        code: authorization.code,
        state: session[:oauth][:state]
      )
    elsif session[:oauth][:response_type] == 'token'
      @access_token, = authorization.issue_tokens_to(
        client, token_types: [:access]
      )

      redirect_to client.redirect_uri_path(
        access_token: @access_token.to_jwt,
        token_type: "Bearer",
        expires_in: 5.minutes,
        scope: "admin",
        state: session[:oauth][:state]
      )
    end
  end
end
