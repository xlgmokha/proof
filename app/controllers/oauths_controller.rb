# frozen_string_literal: true

class OauthsController < ApplicationController
  skip_before_action :authenticate!, only: [:token]
  skip_before_action :authenticate_mfa!, only: [:token]

  def show
    return render_error(:not_found) unless params[:response_type] == 'code'
    @client = Client.find_by!(uuid: params[:client_id])
  end

  def create
    client = Client.find_by!(uuid: params[:client_id])
    authorization = client.authorizations.create!(user: current_user)
    redirect_to client.redirect_uri_path(
      code: authorization.code,
      state: params[:state]
    )
  end

  def token
    response.headers['Cache-Control'] = 'no-store'
    response.headers['Pragma'] = 'no-cache'
    if token_params[:grant_type] == 'authorization_code'
      authorization = Authorization.active.find_by!(code: token_params[:code])
      @access_token, @refresh_token = authorization.exchange
    end
    render formats: :json
  rescue StandardError => error
    Rails.logger.error(error)
    render "bad_request", formats: :json, status: :bad_request
  end

  private

  def token_params
    params.permit(:grant_type, :code)
  end
end
