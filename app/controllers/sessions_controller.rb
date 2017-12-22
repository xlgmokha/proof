class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:new, :destroy]

  def new
    target_binding = request.post? ? :http_post : :http_redirect
    binding = idp.single_sign_on_service_for(binding: target_binding)
    @saml_request = binding.deserialize(saml_params)
    if @saml_request.valid?
      session[:saml] = { params: saml_params.to_h, binding: target_binding }
      return post_back(@saml_request, current_user) if current_user?
    else
      logger.error(@saml_request.errors.full_messages)
      return render_error(:forbidden, model: @saml_request)
    end
  rescue => error
    logger.error(error)
  end

  def create
    if user = User.login(user_params[:email], user_params[:password])
      return redirect_to(dashboard_path) unless session[:saml].present?

      binding = idp.single_sign_on_service_for(binding: session[:saml][:binding])
      saml_request = binding.deserialize(session[:saml][:params])
      return render_error(:forbidden, model: saml_request) if saml_request.invalid?

      post_back(saml_request, user)
    else
      flash[:error] = "Invalid Credentials"
      render :new
    end
  end

  def destroy
    if saml_params[:SAMLRequest].present?
      binding = idp.single_logout_service_for(binding: :http_post)
      saml_request = binding.deserialize(saml_params).tap do |saml|
        raise ActiveRecord::RecordInvalid.new(saml) if saml.invalid?
      end
      raise 'Unknown NameId' unless current_user.uuid == saml_request.name_id

      @url, @saml_params = saml_request.response_for(binding: :http_post, relay_state: saml_params[:RelayState]) do |builder|
        @saml_response_builder = builder
      end
      reset_session
    elsif saml_params[:SAMLResponse].present?
    else
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password)
  end

  def idp
    Idp.default(request)
  end

  def post_back(saml_request, user)
    relay_state = session[:saml][:params][:RelayState]
    @url, @saml_params = saml_request.response_for(user, binding: :http_post, relay_state: relay_state) do |builder|
      @saml_response_builder = builder
    end
    reset_session
    session[:user_id] = user.id
    render :create
  end
end
