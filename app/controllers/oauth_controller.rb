# frozen_string_literal: true

class OauthController < ApplicationController
  def show
    @client = Client.find_by!(uuid: params[:id])
  end

  def create
    client = Client.find_by!(uuid: params[:client_id])
    authorization = client.authorizations.create!(user: current_user)
    redirect_to client.redirect_uri_path(code: authorization.code, state: params[:state])
  end
end
