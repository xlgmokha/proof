# frozen_string_literal: true

class OauthsController < ApplicationController
  skip_before_action :authenticate!, only: [:token]
  before_action :http_basic_authenticate!, only: [:token]

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
    elsif token_params[:grant_type] == 'refresh_token'
      refresh_token = token_params[:refresh_token]
      jti = Token.claims_for(refresh_token, token_type: :refresh)[:jti]
      @access_token, @refresh_token = Token.find_by!(uuid: jti).exchange
    elsif token_params[:grant_type] == 'client_credentials'
      @access_token = current_client.exchange
    else
      return render "bad_request", formats: :json, status: :bad_request
    end
    render formats: :json
  rescue StandardError => error
    Rails.logger.error(error)
    render "bad_request", formats: :json, status: :bad_request
  end

  private

  attr_reader :current_client

  def token_params
    params.permit(:grant_type, :code, :refresh_token)
  end

  def http_basic_authenticate!
    @current_client = authenticate_with_http_basic do |client_id, client_secret|
      Client.find_by(uuid: client_id)&.authenticate(client_secret)
    end
    render "invalid_client", formats: :json, status: :unauthorized unless current_client
  end
end
