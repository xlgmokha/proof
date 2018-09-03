class MfasController < ApplicationController
  def new
  end

  def create
    if current_user.tfa.authenticate(secure_params[:code])
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
