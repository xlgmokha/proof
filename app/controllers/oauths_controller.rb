# frozen_string_literal: true

class OauthsController < ApplicationController
  VALID_RESPONSE_TYPES = [ 'code', 'token' ]

  def show
    @client = Client.find_by!(uuid: params[:client_id])

    if @client.redirect_uri != params[:redirect_uri]
      return redirect_to @client.redirect_uri_path(
        error: 'invalid_request',
        state: params[:state]
      )
    end

    if !VALID_RESPONSE_TYPES.include?(params[:response_type])
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

    if 'code' == session[:oauth][:response_type]
      redirect_to client.redirect_uri_path(
        code: authorization.code,
        state: session[:oauth][:state]
      )
    elsif 'token' == session[:oauth][:response_type]
      @access_token = authorization.issue_tokens_to(client, token_type: :access)

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
