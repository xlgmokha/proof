# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authenticatable
  include Featurable
  protect_from_forgery with: :exception
  around_action :apply_locale
  add_flash_types :error, :warning

  def render_error(status, model: nil)
    @model = model
    render template: "errors/#{status}", status: status
  end

  def apply_locale
    I18n.with_locale(current_user&.locale || I18n.default_locale) do
      yield
    end
  end
end
