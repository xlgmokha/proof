# frozen_string_literal: true

class OauthController < ApplicationController
  def show
    @client = Client.find_by!(uuid: params[:id])
    @authorization = @client.authorizations.build(user: current_user)
  end
end
