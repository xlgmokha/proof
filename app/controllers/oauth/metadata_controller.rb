# frozen_string_literal: true

module Oauth
  class MetadataController < ApplicationController
    skip_before_action :authenticate!

    def show
      request.session_options[:skip] = true
      render formats: :json
    end
  end
end
