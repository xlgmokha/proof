# frozen_string_literal: true

class MfasController < ApplicationController
  skip_before_action :authenticate_mfa!

  def new; end

  def create
    if current_user.tfa.authenticate(secure_params[:code])
      session[:mfa] = { issued_at: Time.now.utc.to_i }
      redirect_to response_path
    else
      redirect_to mfa_path, error: "Invalid code"
    end
  end

  private

  def secure_params
    params.require(:mfa).permit(:code)
  end
end
