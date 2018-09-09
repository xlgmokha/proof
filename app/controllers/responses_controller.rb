# frozen_string_literal: true

class ResponsesController < ApplicationController
  def show
    if session[:saml].present?
      saml = Saml::Kit::Document.to_saml_document(session[:saml][:xml])
      return render_error(:forbidden, model: saml) if saml.invalid?
      post_back(saml, session[:saml][:params][:RelayState])
    else
      redirect_to my_dashboard_path
    end
  end

  private

  def post_back(saml, relay_state)
    if saml.is_a?(Saml::Kit::AuthenticationRequest)
      @url, @saml_params = saml.response_for(
        current_user, binding: :http_post, relay_state: relay_state
      ) do |builder|
        @saml_response_builder = builder
      end
      user_id = current_user.to_param
      mfa_issued_at = session[:mfa].present? ? session[:mfa][:issued_at] : nil
      reset_session
      session[:user_id] = user_id
      session[:mfa] = { issued_at: mfa_issued_at } if mfa_issued_at.present?
    else
      @url, @saml_params = saml.response_for(
        binding: :http_post, relay_state: relay_state
      ) do |builder|
        @saml_response_builder = builder
      end
      reset_session
    end
  end
end
