# frozen_string_literal: true

module Authentication
  extend ActiveSupport::Concern
  included do
    before_action :set_current_request_details
    before_action :authenticate!
    before_action :authenticate_mfa!
    helper_method :current_user, :current_user?
  end

  def current_user
    Current.user
  end

  def current_user?
    Current.user?
  end

  private

  def authenticate!
    redirect_to new_session_path unless current_user?
  end

  def authenticate_mfa!
    return unless Current.user?
    mfa = Current.user.mfa
    redirect_to new_mfa_path unless mfa.valid_session?(session[:mfa])
  end

  def set_current_request_details(uuid: session[:user_id])
    Current.request_id = request.uuid
    Current.user_agent = request.user_agent
    Current.ip_address = request.ip
    Current.user = User.find_by(uuid: uuid) if uuid.present?
  end
end
