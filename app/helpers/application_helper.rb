# frozen_string_literal: true

module ApplicationHelper
  def alert_class_for(type)
    case type.to_sym
    when :notice
      'alert-success'
    when :warning
      'alert-warning'
    when :error
      'alert-danger'
    else
      'alert-primary'
    end
  end

  def alert_message_for(type)
    case type.to_sym
    when :notice
      'Hot dog!'
    when :warning
      'Holy guacamole!'
    when :error
      'Danger Will Robinson!'
    else
      '🤷'
    end
  end

  def scim_type_for(error)
    case error
    when ActiveRecord::RecordInvalid
      errors = error.record.errors.full_messages
      if errors.count == 1 &&
         errors[0].end_with?('has already been taken')
        return 'uniqueness'
      end
    end
    "invalidValue"
  end
end
