# frozen_string_literal: true

module Oauth
  class MetadataController < ApplicationController
    skip_before_action :authenticate!
    before_action do
      request.session_options[:skip] = true
    end

    def show
      render formats: :json
    end
  end
end
