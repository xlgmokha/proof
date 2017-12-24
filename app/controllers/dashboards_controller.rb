class DashboardsController < ApplicationController
  def show
    @metadatum = Saml::Kit.registry.to_a
  end
end
