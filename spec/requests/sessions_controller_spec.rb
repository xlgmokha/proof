require 'rails_helper'

describe SessionsController do
  let(:registry) { Saml::Kit::DefaultRegistry.new }
  let(:issuer) { Saml::Kit.configuration.entity_id }
  let(:sp_metadata) do
    Saml::Kit::ServiceProviderMetadata.build do |x|
      x.add_assertion_consumer_service(FFaker::Internet.uri("https"), binding: :http_post)
      x.add_single_logout_service(FFaker::Internet.uri("https"), binding: :http_post)
    end
  end
  def http_login(user)
    post '/session', params: { user: { email: user.email, password: user.password } }
  end
  before { Saml::Kit.configuration.registry = registry }

  describe '#new' do
    describe "POST #new" do
      let(:post_binding) { Saml::Kit::Bindings::HttpPost.new(location: new_session_url) }
      let(:user) { create(:user) }
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
        expect(session[:saml][:params]).to be_present
        expect(session[:saml][:xml]).to be_present
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

      it 'renders a login page when there is no SAML Request' do
        post '/session/new'
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Login")
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

  describe "#create" do
    let(:user) { User.create!(email: FFaker::Internet.email, password: password) }
    let(:password) { FFaker::Internet.password }

    context "when a SAMLRequest is not present" do
      before { post '/session', params: { user: { email: user.email, password: password } } }
      specify { expect(response).to redirect_to(my_dashboard_path) }
    end

    it 'posts the response back to the ACS endpoint' do
      allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
      redirect_binding = Saml::Kit::Bindings::HttpRedirect.new(location: new_session_url)
      get redirect_binding.serialize(Saml::Kit::AuthenticationRequest.builder)[0]

      post '/session', params: { user: { email: user.email, password: password } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(sp_metadata.assertion_consumer_service_for(binding: :http_post).location)
      expect(response.body).to include('SAMLResponse')
    end

    it 'includes the RelayState in the response' do
      relay_state = SecureRandom.uuid
      allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
      redirect_binding = Saml::Kit::Bindings::HttpRedirect.new(location: new_session_url)

      get redirect_binding.serialize(Saml::Kit::AuthenticationRequest.builder, relay_state: relay_state)[0]

      post '/session', params: { user: { email: user.email, password: password } }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('RelayState')
      expect(response.body).to include(relay_state)
    end
  end

  describe "#destroy" do
    let(:post_binding) { Saml::Kit::Bindings::HttpPost.new(location: "/session/logout") }
    let(:user) { User.create!(email: FFaker::Internet.email, password: FFaker::Internet.password) }

    it 'posts the response back to the service provider' do
      allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
      builder = Saml::Kit::LogoutRequest.builder(user) do |x|
        x.issuer = issuer
        x.embed_signature = false
      end

      http_login(user)

      url, saml_params = post_binding.serialize(builder)
      post url, params: saml_params
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("SAMLResponse")
      expect(response.body).to include(sp_metadata.single_logout_service_for(binding: :http_post).location)
    end

    it 'redirects to the login page' do
      allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
      authn_request = Saml::Kit::AuthenticationRequest.build
      builder = Saml::Kit::LogoutResponse.builder(authn_request) do |x|
        x.issuer = issuer
        x.embed_signature = false
      end

      url, saml_params = post_binding.serialize(builder)
      post url, params: saml_params
      expect(response).to redirect_to(new_session_url)
    end

    context "when logging out of the IDP only" do
      let(:user) { create(:user) }

      def session_id_from(response)
        cookies = response.headers['Set-Cookie']
        return if cookies.nil?
        cookies.split("\;")[0].split("=")[1]
      end

      before :each do
        http_login(user)
        @session_id = session_id_from(response)
        delete session_path
      end

      specify { expect(session_id_from(response)).not_to eql(@session_id) }
      specify { expect(session_id_from(response)).to be_present }
      specify { expect(response).to redirect_to(new_session_path) }
    end
  end
end
