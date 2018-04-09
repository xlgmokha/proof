# frozen_string_literal: true

class TfasController < ApplicationController
  def new
    return redirect_to edit_tfa_path if current_user.tfa_setup?
    current_user.tfa_secret = ::ROTP::Base32.random_base32
  end

  def create
    current_user.update!(params.require(:user).permit(:tfa_secret))
    redirect_to dashboard_path
  end

  def edit; end

  def destroy
    current_user.disable_tfa!
    redirect_to dashboard_path
  end
end
