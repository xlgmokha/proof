class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:new, :destroy]
  skip_before_action :authenticate!, only: [:new, :create, :destroy]

  def new
    binding = binding_for(request.post? ? :http_post : :http_redirect, new_session_url)
    @saml_request = binding.deserialize(saml_params)
    if @saml_request.valid?
      session[:saml] = { params: saml_params.to_h, xml: @saml_request.to_xml }
      return post_back(@saml_request, current_user) if current_user?
    else
      render_error(:forbidden, model: @saml_request)
    end
  rescue => error
    logger.error(error)
  end

  def create
    user_params = params.require(:user).permit(:email, :password)
    if user = User.login(user_params[:email], user_params[:password])
      unless session[:saml].present?
        login(user)
        return redirect_to(dashboard_path)
      end

      saml_request = Saml::Kit::AuthenticationRequest.new(session[:saml][:xml])
      if saml_request.invalid?
        render_error(:forbidden, model: saml_request)
      else
        post_back(saml_request, user)
      end
    else
      flash[:error] = "Invalid Credentials"
      render :new
    end
  end

  def destroy
    binding = binding_for(:http_post, session_url)
    if saml_params[:SAMLRequest].present?
      saml_request = binding.deserialize(saml_params).tap do |saml|
        raise ActiveRecord::RecordInvalid.new(saml) if saml.invalid?
      end
      raise 'Unknown NameId' unless current_user.uuid == saml_request.name_id

      @url, @saml_params = saml_request.response_for(binding: :http_post, relay_state: saml_params[:RelayState]) do |builder|
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
    end
  end

  private

  def post_back(saml_request, user)
    relay_state = session[:saml][:params][:RelayState]
    @url, @saml_params = saml_request.response_for(user, binding: :http_post, relay_state: relay_state) do |builder|
      @saml_response_builder = builder
    end
    login(user)
    render :create
  end

  def login(user)
    reset_session
    session[:user_id] = user.id
  end
end
