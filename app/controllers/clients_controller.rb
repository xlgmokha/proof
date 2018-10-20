# frozen_string_literal: true

class ClientsController < ApplicationController
  skip_before_action :authenticate!
  before_action :apply_cache_headers

  def create
    @client = Client.create!(transform(secure_params))
    render status: :created, formats: :json
  rescue ActiveRecord::RecordInvalid => error
    json = {
      error: error_type_for(error.record.errors),
      error_description: error.record.errors.full_messages.join(' ')
    }
    render json: json, status: :bad_request
  end

  private

  def secure_params
    params.permit(
      :client_name,
      :token_endpoint_auth_method,
      :logo_uri,
      :jwks_uri,
      redirect_uris: []
    )
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

  def error_type_for(errors)
    if errors[:redirect_uris].present?
      :invalid_redirect_uri
    else
      :invalid_client_metadata
    end
  end
end
