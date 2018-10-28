# frozen_string_literal: true

module Oauth
  class MetadataController < ApplicationController
    skip_before_action :authenticate!

    def show
      render formats: :json
    end
  end
end
