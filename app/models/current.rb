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
end
