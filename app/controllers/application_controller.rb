# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Authenticatable
  protect_from_forgery with: :exception
  add_flash_types :error, :warning

  def render_error(status, model: nil)
    @model = model
    render template: "errors/#{status}", status: status
  end
end
