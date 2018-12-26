# frozen_string_literal: true

module ApplicationHelper
  def alert_class_for(type)
    case type.to_sym
    when :notice
      'is-success'
    when :warning
      'is-warning'
    when :error
      'is-danger'
    else
      'is-info'
    end
  end

  def flash_error_messages_for(item)
    if item.is_a?(ActiveModel::Errors)
      item.keys.map do |key|
        item.full_messages_for(key).join(' ')
      end
    else
      Array(item)
    end
  end

  def audit_icon_for(audit)
    case audit.auditable_type
    when 'User'
      'fa-user'
    when 'UserSession'
      'fa-bookmark'
    else
      'fa-archive'
    end
  end
end
