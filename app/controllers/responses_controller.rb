# frozen_string_literal: true

class ResponsesController < ApplicationController
  def show
    if session[:saml].present?
      saml_request = Saml::Kit::AuthenticationRequest.new(session[:saml][:xml])
      if saml_request.invalid?
        return render_error(:forbidden, model: saml_request)
      end
      post_back(saml_request)
    else
      redirect_to my_dashboard_path
    end
  end

  private

  def post_back(saml_request)
    relay_state = session[:saml][:params][:RelayState]
    @url, @saml_params = saml_request.response_for(
      current_user, binding: :http_post, relay_state: relay_state
    ) do |builder|
      @saml_response_builder = builder
    end
    render template: 'sessions/create'
  end
end
