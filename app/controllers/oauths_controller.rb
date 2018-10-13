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
    response_type = session[:oauth][:response_type]
    state = session[:oauth][:state]
    redirect_to client.redirect_uri_for(authorization, response_type, state)
  end
end
