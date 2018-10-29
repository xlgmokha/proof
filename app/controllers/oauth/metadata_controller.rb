# frozen_string_literal: true

module Oauth
  class MetadataController < ActionController::API
    def show
      render formats: :json
    end
  end
end
