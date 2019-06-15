# frozen_string_literal: true

class MfasController < ApplicationController
  skip_before_action :authenticate_mfa!

  def new; end

  def create
    if current_user.mfa.authenticate(secure_params[:code])
      reset_session
      session[:user_session_key] = Current.user_session.key
      session[:mfa] = { issued_at: Time.current.utc.to_i }
      redirect_to response_path
    else
      redirect_to new_mfa_path, error: "Invalid code"
    end
  end

  private

  def secure_params
    params.require(:mfa).permit(:code)
  end
end
