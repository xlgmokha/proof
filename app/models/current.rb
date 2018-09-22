# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user, :token
  attribute :request
  attribute :user_session
  attribute :request_id, :user_agent, :ip_address

  def user?
    user.present?
  end

  def token=(token)
    super
    self.user = token&.subject
  end

  def access(request, session)
    self.request = request
    self.user_session = UserSession.authenticate(session[:user_session_key])
    self.user = user_session&.user
    session[:user_session_key] = user_session&.access(request)
  end
end
