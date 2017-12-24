require 'rails_helper'

describe MetadataController do
  describe "#show" do
    before { get '/metadata' }

    it 'returns the metadata' do
      expect(response).to have_http_status(:ok)
      metadata = Saml::Kit::Metadata.from(response.body)
      expect(metadata.entity_id).to eql(Saml::Kit.configuration.issuer)
    end

    it 'uses the correct content type' do
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/samlmetadata+xml")
    end
  end
end
