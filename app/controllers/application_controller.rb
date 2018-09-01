# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include SamlRespondable
  protect_from_forgery with: :exception
  before_action :authenticate!
  helper_method :current_user
  add_flash_types :error, :warning

  def render_error(status, model: nil)
    @model = model
    render template: "errors/#{status}", status: status
  end

  def current_user
    return nil if session[:user_id].blank?
    @current_user ||= User.find(session[:user_id])
  rescue ActiveRecord::RecordNotFound => error
    logger.error(error)
    nil
  end

  def current_user?
    current_user.present?
  end

  private

  def authenticate!
    redirect_to new_session_path unless current_user?
  end
end
