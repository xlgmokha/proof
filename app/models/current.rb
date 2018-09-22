# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user, :token
  attribute :request
  attribute :session
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
    self.session = session
    uuid = session[:user_id]
    self.user = User.find_by(uuid: uuid) if uuid.present?
  end
end
