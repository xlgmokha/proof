# frozen_string_literal: true

class OauthsController < ApplicationController
  VALID_RESPONSE_TYPES = %w[code token].freeze

  def show
    @client = Client.find_by!(uuid: params[:client_id])

    return redirect_to @client.redirect_url(
      error: :invalid_request,
      state: params[:state]
    ) unless @client.valid_redirect_uri?(params[:redirect_uri])

    return redirect_to @client.redirect_url(
      error: :unsupported_response_type,
      state: params[:state]
    ) unless @client.valid_response_type?(params[:response_type])

    session[:oauth] = {
      client_id: params[:client_id],
      response_type: params[:response_type],
      state: params[:state],
    }
  end

  def create(oauth = session[:oauth])
    return render_error(:bad_request) if oauth.nil?

    client = Client.find_by!(uuid: oauth[:client_id])
    redirect_to client.redirect_url_for(
      current_user,
      oauth[:response_type],
      oauth[:state]
    )
  end
end
