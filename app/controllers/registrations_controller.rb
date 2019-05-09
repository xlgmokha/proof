# frozen_string_literal: true

class RegistrationsController < ApplicationController
  skip_before_action :authenticate!

  def new
    @user = User.new
  end

  def create
    User.create!(user_params)
    redirect_to new_session_path
  rescue ActiveRecord::RecordInvalid => error
    redirect_to new_registration_path, error: error.record.errors
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
