require 'rails_helper'

describe SessionsController do
  let(:registry) { Saml::Kit::DefaultRegistry.new }
  let(:issuer) { Saml::Kit.configuration.issuer }
  let(:sp_metadata) do
    Saml::Kit::ServiceProviderMetadata.build do |x|
      x.add_assertion_consumer_service(FFaker::Internet.uri("https"), binding: :http_post)
    end
  end
  def http_login(user)
    post '/session', params: { user: { email: user.email, password: user.password } }
  end
  before { Saml::Kit.configuration.registry = registry }

  describe '#new' do
    describe "POST #new" do
      let(:post_binding) { Saml::Kit::Bindings::HttpPost.new(location: new_session_url) }
      let(:user) { User.create!(email: FFaker::Internet.email, password: FFaker::Internet.password) }
      let(:saml_params) { post_binding.serialize(Saml::Kit::AuthenticationRequest.builder)[1] }


      it 'renders an error page when the service provider is not registered' do
        url, saml_params = post_binding.serialize(Saml::Kit::AuthenticationRequest.builder)
        post url, params: saml_params
        expect(response).to have_http_status(:forbidden)
        expect(response.body).to include("Forbidden")
      end

      it 'renders the login page when the service provider is registered and the user is not logged in' do
        allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
        url, saml_params = post_binding.serialize(Saml::Kit::AuthenticationRequest.builder)
        post url, params: saml_params

        expect(response).to have_http_status(:ok)
        expect(session[:saml]).to be_present
        expect(session[:saml][:binding]).to eql(:http_post)
      end

      it 'generates a response for the user when they are already logged in' do
        allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
        url, saml_params = post_binding.serialize(Saml::Kit::AuthenticationRequest.builder)

        post url, params: saml_params
        http_login(user)
        post url, params: saml_params

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Sending Response to Service Provider")
      end
    end

    describe "GET #new" do
      let(:redirect_binding) { Saml::Kit::Bindings::HttpRedirect.new(location: new_session_url) }

      it 'renders an error page when the service provider is not registered' do
        get redirect_binding.serialize(Saml::Kit::AuthenticationRequest.builder)[0]
        expect(response).to have_http_status(:forbidden)
        expect(response.body).to include("Forbidden")
      end

      it 'renders the login page when the sp is registered' do
        allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
        get redirect_binding.serialize(Saml::Kit::AuthenticationRequest.builder)[0]
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Login")
      end
    end
  end
end
