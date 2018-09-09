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
    render json: {
      access_token: SecureRandom.hex(20),
      token_type: 'access',
      expires_in: 1.hour.to_i,
      refresh_token: SecureRandom.hex(20)
    }, status: :ok
  end
end
