# frozen_string_literal: true

class OauthsController < ApplicationController
  def show
    return render_error(:not_found) unless params[:response_type] == 'code' || params[:response_type] == 'token'

    @client = Client.find_by!(uuid: params[:client_id])
    session[:oauth] = {
      client_id: params[:client_id],
      response_type: params[:response_type],
      state: params[:state],
    }

  end

  def create
    client = Client.find_by!(uuid: session[:oauth][:client_id])
    authorization = client.authorizations.create!(user: current_user)

    if 'code' == session[:oauth][:response_type]
      redirect_to client.redirect_uri_path(
        code: authorization.code,
        state: session[:oauth][:state]
      )
    elsif 'token' == session[:oauth][:response_type]
      @access_token, _ = authorization.issue_tokens_to(client)

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
