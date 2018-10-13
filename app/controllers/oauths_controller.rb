# frozen_string_literal: true

class OauthsController < ApplicationController
  VALID_RESPONSE_TYPES = %w[code token].freeze

  def show
    @client = Client.find_by!(uuid: secure_params[:client_id])

    unless @client.valid_redirect_uri?(secure_params[:redirect_uri])
      return redirect_to @client.redirect_url(
        error: :invalid_request,
        state: secure_params[:state]
      )
    end

    unless @client.valid_response_type?(secure_params[:response_type])
      return redirect_to @client.redirect_url(
        error: :unsupported_response_type,
        state: secure_params[:state]
      )
    end

    session[:oauth] = {
      client_id: secure_params[:client_id],
      response_type: secure_params[:response_type],
      state: secure_params[:state],
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
  rescue StandardError
    redirect_to client.redirect_url(error: :invalid_request)
  end

  private

  def secure_params
    params.permit(:client_id, :response_type, :redirect_uri, :state)
  end
end
