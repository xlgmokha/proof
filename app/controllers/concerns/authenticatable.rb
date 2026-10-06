# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern
  included do
    before_action :apply_current_request_details
    before_action :authenticate!
    before_action :authenticate_mfa!
    helper_method :current_user, :current_user?, :mfa_completed?
  end

  def current_user
    Current.user
  end

  def current_user?
    Current.user?
  end

  def mfa_completed?
    Current.user.mfa.valid_session?(session[:mfa])
  end

  private

  # What has to survive a new login to get the user back to where they were.
  RETURN_KEYS = %i[return_to reauthenticated_for].freeze

  def authenticate!
    return if current_user?

    # Only the OAuth authorization page is returned to, and only by path.
    session[:return_to] = request.fullpath if request.get? && request.path.start_with?('/oauth/')
    redirect_to new_session_path
  end

  def return_state
    RETURN_KEYS.index_with { |key| session[key] }.compact
  end

  def restore_return_state(state)
    state.each { |key, value| session[key] = value }
  end

  # Where to go after signing in: back to the page that asked for it.
  def return_path
    path = session.delete(:return_to).to_s
    path if path.start_with?('/oauth/') && !path.start_with?('//')
  end

  def authenticate_mfa!
    return unless Current.user?

    redirect_to new_mfa_path unless mfa_completed?
  end

  def apply_current_request_details
    Current.access(request, session)
  end
end
