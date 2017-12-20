require 'rails_helper'

describe SessionsController do
  describe '#new' do
    let(:post_binding) { Saml::Kit::Bindings::HttpPost.new(location: new_session_url) }
    let(:registry) { Saml::Kit::DefaultRegistry.new }
    let(:issuer) { Saml::Kit.configuration.issuer }
    let(:sp_metadata) { Saml::Kit::ServiceProviderMetadata.build }

    before { Saml::Kit.configuration.registry = registry }

    it 'renders an error page when the service provider is not registered' do
      saml_params = post_binding.serialize(Saml::Kit::AuthenticationRequest.builder)[1]
      post :new, params: saml_params
      expect(response).to have_http_status(:forbidden)
    end

    it 'renders the login page when the service provider is registered and the user is not logged in' do
      saml_params = post_binding.serialize(Saml::Kit::AuthenticationRequest.builder)[1]
      allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
      post :new, params: saml_params

      expect(response).to have_http_status(:ok)
      expect(session[:saml]).to be_present
      expect(session[:saml][:binding]).to eql(:http_post)
    end
  end
end
