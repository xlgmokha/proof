# frozen_string_literal: true

class SessionsController < ApplicationController
  ALLOWED_SAML_PARAMS = [
    :RelayState,
    :SAMLEncoding,
    :SAMLRequest,
    :SAMLResponse,
    :SigAlg,
    :Signature,
  ].freeze
  skip_before_action :verify_authenticity_token, only: [:new, :destroy]
  skip_before_action :authenticate!, only: [:new, :show, :create, :destroy]

  def new
    binding = binding_for(
      request.post? ? :http_post : :http_redirect, new_session_url
    )
    @saml = binding.deserialize(saml_params)
    return render_error(:forbidden, model: @saml) if @saml.invalid?

    session[:saml] = { params: saml_params.to_h, xml: @saml.to_xml }
    redirect_to response_path if current_user?
  rescue StandardError => error
    logger.error(error)
    redirect_to my_dashboard_path if current_user?
  end

  def show
    render layout: nil
  end

  def create
    user_params = params.require(:user).permit(:email, :password)
    if (user = User.login(user_params[:email], user_params[:password]))
      login(user)
      redirect_to response_path
    else
      redirect_to new_session_path, error: "Invalid Credentials"
    end
  end

  def destroy
    binding = binding_for(:http_post, session_url)
    if saml_params[:SAMLRequest].present?
      saml = binding.deserialize(saml_params)
      raise ActiveRecord::RecordInvalid.new(saml) if saml.invalid?
      raise 'Unknown NameId' unless current_user.to_param == saml.name_id

      session[:saml] = { params: saml_params.to_h, xml: saml.to_xml }
      redirect_to response_path
    elsif saml_params[:SAMLResponse].present?
      saml = binding.deserialize(saml_params)
      raise ActiveRecord::RecordInvalid.new(saml) if saml.invalid?

      reset_session
      redirect_to new_session_path
    else
      Current.user_session&.destroy
      reset_session
      redirect_to new_session_path
    end
  end

  private

  def login(user)
    saml_data = session[:saml]
    reset_session
    session[:user_session_key] = user.sessions.build.access(request)
    session[:saml] = saml_data
  end

  def binding_for(binding, location)
    if binding == :http_post
      Saml::Kit::Bindings::HttpPost.new(location: location)
    else
      Saml::Kit::Bindings::HttpRedirect.new(location: location)
    end
  end

  def saml_params(allowed_params = ALLOWED_SAML_PARAMS)
    @saml_params ||=
      if request.post?
        params.permit(*allowed_params)
      else
        query_string = request.query_string
        on = query_string.include?("&amp;") ? "&amp;" : "&"
        result = Hash[query_string.split(on).map { |x| x.split("=", 2) }]
        result = result.symbolize_keys
        result.select! { |key, _value| allowed_params.include?(key.to_sym) }
        result
      end
  end
end
