# frozen_string_literal: true

module My
  class DashboardsController < ApplicationController
    def show
      @metadatum = Saml::Kit.registry.to_a
    end
  end
end
