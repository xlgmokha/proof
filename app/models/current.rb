# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user, :token
  attribute :request_id, :user_agent, :ip_address

  def user?
    user.present?
  end

  def token=(token)
    super
    self.user = token&.subject
  end

  def access(request, session)
    self.request_id = request.uuid
    self.user_agent = request.user_agent
    self.ip_address = request.ip
    uuid = session[:user_id]
    self.user = User.find_by(uuid: uuid) if uuid.present?
  end
end
