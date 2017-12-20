require 'rails_helper'

describe SessionsController do
  describe '#new' do
    render_views

    let(:post_binding) { Saml::Kit::Bindings::HttpPost.new(location: new_session_url) }
    let(:registry) { Saml::Kit::DefaultRegistry.new }
    let(:issuer) { Saml::Kit.configuration.issuer }
    let(:sp_metadata) do
      Saml::Kit::ServiceProviderMetadata.build do |x|
        x.add_assertion_consumer_service(FFaker::Internet.uri("https"), binding: :http_post)
      end
    end
    let(:user) { User.create!(email: FFaker::Internet.email, password: FFaker::Internet.password) }
    let(:saml_params) { post_binding.serialize(Saml::Kit::AuthenticationRequest.builder)[1] }

    before { Saml::Kit.configuration.registry = registry }

    it 'renders an error page when the service provider is not registered' do
      post :new, params: saml_params
      expect(response).to have_http_status(:forbidden)
    end

    it 'renders the login page when the service provider is registered and the user is not logged in' do
      allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
      post :new, params: saml_params

      expect(response).to have_http_status(:ok)
      expect(session[:saml]).to be_present
      expect(session[:saml][:binding]).to eql(:http_post)
    end

    it 'generates a response for the user when they are already logged in' do
      allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
      session[:user_id] = user.id

      post :new, params: saml_params

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sending Response to Service Provider")
    end
  end
end
