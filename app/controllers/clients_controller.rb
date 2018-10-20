class ClientsController < ApplicationController
  skip_before_action :authenticate!
  before_action :apply_cache_headers

  def create
    @client = Client.create!(transform(secure_params))
    render status: :created, formats: :json
  end

  private

  def secure_params
    params.permit(:client_name, :token_endpoint_auth_method, :logo_uri, :jwks_uri, redirect_uris: [])
  end

  def transform(params)
    {
      name: params[:client_name],
      redirect_uris: params[:redirect_uris],
      token_endpoint_auth_method: params[:token_endpoint_auth_method],
      logo_uri: params[:logo_uri],
      jwks_uri: params[:jwks_uri],
    }
  end

  def apply_cache_headers
    response.headers["Cache-Control"] = "no-cache, no-store"
    response.headers["Pragma"] = "no-cache"
  end
end
