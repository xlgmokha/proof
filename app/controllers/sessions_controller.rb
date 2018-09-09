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
  skip_before_action :authenticate!, only: [:new, :create, :destroy]

  def new
    binding = binding_for(
      request.post? ? :http_post : :http_redirect, new_session_url
    )
    @saml_request = binding.deserialize(saml_params)
    if @saml_request.valid?
      session[:saml] = { params: saml_params.to_h, xml: @saml_request.to_xml }
      return post_back(@saml_request, current_user) if current_user?
    else
      render_error(:forbidden, model: @saml_request)
    end
  rescue StandardError => error
    logger.error(error)
    redirect_to my_dashboard_path if current_user?
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
      saml_request = binding.deserialize(saml_params).tap do |saml|
        raise ActiveRecord::RecordInvalid.new(saml) if saml.invalid?
      end
      raise 'Unknown NameId' unless current_user.uuid == saml_request.name_id

      @url, @saml_params = saml_request.response_for(
        binding: :http_post, relay_state: saml_params[:RelayState]
      ) do |builder|
        @saml_response_builder = builder
      end
      reset_session
    elsif saml_params[:SAMLResponse].present?
      saml_request = binding.deserialize(saml_params)
      if saml_request.invalid?
        raise ActiveRecord::RecordInvalid.new(saml_request)
      end
      reset_session
      redirect_to new_session_path
    else
      reset_session
      redirect_to new_session_path
    end
  end

  private

  def post_back(saml_request, user)
    relay_state = session[:saml][:params][:RelayState]
    @url, @saml_params = saml_request.response_for(
      user, binding: :http_post, relay_state: relay_state
    ) do |builder|
      @saml_response_builder = builder
    end
    login(user)
    render :create
  end

  def login(user)
    saml_data = session[:saml]
    reset_session
    session[:user_id] = user.to_param
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
