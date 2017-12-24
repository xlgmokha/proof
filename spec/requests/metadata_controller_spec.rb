require 'rails_helper'

describe MetadataController do
  describe "#show" do
    it 'returns the metadata' do
      get '/metadata'

      expect(response).to have_http_status(:ok)
      metadata = Saml::Kit::Metadata.from(response.body)
      expect(metadata.entity_id).to eql(Saml::Kit.configuration.issuer)
    end
  end
end
