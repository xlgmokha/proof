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

    if params[:grant_type] == 'authorization_code'
      authorization = current_client.authorizations.active.find_by!(code: params[:code])
      @access_token, @refresh_token = authorization.issue_tokens_to(current_client)
    elsif params[:grant_type] == 'refresh_token'
      refresh_token = params[:refresh_token]
      jti = Token.claims_for(refresh_token, token_type: :refresh)[:jti]
      @access_token, @refresh_token = Token.find_by!(uuid: jti).issue_tokens_to(current_client)
    elsif params[:grant_type] == 'client_credentials'
      @access_token = current_client.access_token
    elsif params[:grant_type] == 'password'
      user = User.login(params[:username], params[:password])
      return render "bad_request", formats: :json, status: :bad_request unless user
      @access_token, @refresh_token = user.issue_tokens_to(current_client)
    elsif params[:grant_type] == 'urn:ietf:params:oauth:grant-type:saml2-bearer'
      assertion = Saml::Kit::Assertion.new(Base64.urlsafe_decode64(params[:assertion]))
      return render "bad_request", formats: :json, status: :bad_request if assertion.invalid?
      user = assertion.name_id_format == Saml::Kit::Namespaces::PERSISTENT ?
        User.find_by!(uuid: assertion.name_id) :
        User.find_by!(email: assertion.name_id)
      @access_token, @refresh_token = user.issue_tokens_to(current_client)
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

  def http_basic_authenticate!
    @current_client = authenticate_with_http_basic do |client_id, client_secret|
      Client.find_by(uuid: client_id)&.authenticate(client_secret)
    end
    render "invalid_client", formats: :json, status: :unauthorized unless current_client
  end
end
