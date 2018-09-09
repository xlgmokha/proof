# frozen_string_literal: true

class ResponsesController < ApplicationController
  def show
    if session[:saml].present?
      saml = Saml::Kit::AuthenticationRequest.new(session[:saml][:xml])
      return render_error(:forbidden, model: saml) if saml.invalid?
      post_back(saml, session[:saml][:params][:RelayState])
    else
      redirect_to my_dashboard_path
    end
  end

  private

  def post_back(saml, relay_state)
    @url, @saml_params = saml.response_for(
      current_user, binding: :http_post, relay_state: relay_state
    ) do |builder|
      @saml_response_builder = builder
    end
  end
end
