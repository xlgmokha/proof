# frozen_string_literal: true

class OauthsController < ApplicationController
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
end
