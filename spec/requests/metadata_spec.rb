# frozen_string_literal: true

require 'rails_helper'

describe '/metadata' do
  describe "GET /metadata" do
    before { get '/metadata' }

    specify { expect(Saml::Kit::Metadata.from(response.body)).to be_valid }
    specify { expect(Saml::Kit::Metadata.from(response.body).entity_id).to eql(Saml::Kit.configuration.entity_id) }
    specify { expect(response).to have_http_status(:ok) }
    specify { expect(response.content_type).to start_with("application/samlmetadata+xml;") }
  end
end
