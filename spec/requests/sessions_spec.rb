# frozen_string_literal: true

require 'rails_helper'

describe "/sessions" do
  let(:registry) { Saml::Kit::DefaultRegistry.new }
  let(:issuer) { Saml::Kit.configuration.entity_id }
  let(:sp_metadata) do
    Saml::Kit::ServiceProviderMetadata.build do |x|
      x.add_assertion_consumer_service(FFaker::Internet.uri("https"), binding: :http_post)
      x.add_single_logout_service(FFaker::Internet.uri("https"), binding: :http_post)
    end
  end

  before { Saml::Kit.configuration.registry = registry }

  def session_id_from(response)
    cookies = response.headers['Set-Cookie']
    return if cookies.nil?

    cookies.split("\;")[0].split("=")[1]
  end

  describe "POST /session/new" do
    let(:post_binding) { Saml::Kit::Bindings::HttpPost.new(location: new_session_url) }

    context "when the user is already logged in" do
      let(:user) { create(:user) }

      before { http_login(user) }

      context "when a registered SAML request is provided" do
        before do
          allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
          url, saml_params = post_binding.serialize(Saml::Kit::AuthenticationRequest.builder)
          post url, params: saml_params
          follow_redirect!
        end

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.body).to include("Sending Response to Service Provider") }
      end

      context "when an unregistered SAML request is provided" do
        before do
          url, saml_params = post_binding.serialize(Saml::Kit::AuthenticationRequest.builder)
          post url, params: saml_params
        end

        specify { expect(response).to have_http_status(:forbidden) }
      end

      context "when a SAML request is not provided" do
        before { post '/session/new' }

        specify { expect(response).to redirect_to(my_dashboard_path) }
      end
    end

    context "when the user is not logged in" do
      context "when a registered SAML request is provided" do
        before do
          allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
          url, saml_params = post_binding.serialize(Saml::Kit::AuthenticationRequest.builder)
          post url, params: saml_params
        end

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(session[:saml]).to be_present }
        specify { expect(session[:saml][:params]).to be_present }
        specify { expect(session[:saml][:xml]).to be_present }
      end

      context "when an unregistered SAML request is provided" do
        before do
          url, saml_params = post_binding.serialize(Saml::Kit::AuthenticationRequest.builder)
          post url, params: saml_params
        end

        specify { expect(response).to have_http_status(:forbidden) }
      end

      context "when a SAML request is not provided" do
        before { post '/session/new' }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.body).to include("Login") }
      end
    end
  end

  describe "GET /session" do
    let(:user) { create(:user) }

    before { http_login(user) }

    context 'when logged in' do
      before { get '/session' }

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.body).to include(I18n.t('sessions.show.logout')) }
    end
  end

  describe "GET /session/new" do
    let(:redirect_binding) { Saml::Kit::Bindings::HttpRedirect.new(location: new_session_url) }

    context "when the user is already logged in" do
      before { http_login(create(:user)) }

      context "when a registered SAML request is provided" do
        before do
          allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
          get redirect_binding.serialize(Saml::Kit::AuthenticationRequest.builder)[0]
          follow_redirect!
        end

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.body).to include("Sending Response to Service Provider") }
      end

      context "when an unregistered SAML request is provided" do
        before { get redirect_binding.serialize(Saml::Kit::AuthenticationRequest.builder)[0] }

        specify { expect(response).to have_http_status(:forbidden) }
      end

      context "when a SAML request is not provided" do
        before { get '/session/new' }

        specify { expect(response).to redirect_to(my_dashboard_path) }
      end
    end

    context "when the user is not logged in" do
      context "when a registered SAML request is provided" do
        before do
          allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
          get redirect_binding.serialize(Saml::Kit::AuthenticationRequest.builder)[0]
        end

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(session[:saml]).to be_present }
        specify { expect(session[:saml][:params]).to be_present }
        specify { expect(session[:saml][:xml]).to be_present }
      end

      context "when an unregistered SAML request is provided" do
        before { get redirect_binding.serialize(Saml::Kit::AuthenticationRequest.builder)[0] }

        specify { expect(response).to have_http_status(:forbidden) }
      end

      context "when a SAML request is not provided" do
        before { get '/session/new' }

        specify { expect(response).to have_http_status(:ok) }
        specify { expect(response.body).to include("Login") }
      end
    end
  end

  describe "POST /session" do
    let(:user) { create(:user) }
    let(:password) { user.password }

    context "when a SAMLRequest is not present" do
      context "when the credentials are correct" do
        before { post '/session', params: { user: { email: user.email, password: password } } }

        specify { expect(response).to redirect_to(response_path) }
      end

      context "when the credentials are incorrect" do
        before { post '/session', params: { user: { email: user.email, password: 'incorrect' } } }

        specify { expect(response).to redirect_to(new_session_path) }
        specify { expect(flash[:error]).to include('Invalid Credentials') }
      end
    end

    context "when a SAMLRequest is found in session" do
      let(:redirect_binding) { Saml::Kit::Bindings::HttpRedirect.new(location: new_session_url) }
      let(:relay_state) { SecureRandom.uuid }

      before do
        allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
        get redirect_binding.serialize(Saml::Kit::AuthenticationRequest.builder, relay_state: relay_state)[0]
      end

      context "when the credentials are correct" do
        before { post '/session', params: { user: { email: user.email, password: password } } }

        specify { expect(response).to redirect_to(response_path) }
        specify { expect(session[:saml]).to be_present }
        specify { expect(session[:saml][:params][:RelayState]).to eql(relay_state) }
      end

      context "when the credentials are incorrect" do
        before { post '/session', params: { user: { email: user.email, password: 'incorrect' } } }

        specify { expect(response).to redirect_to(new_session_path) }
        specify { expect(flash[:error]).to include('Invalid Credentials') }
      end
    end
  end

  describe "DELETE /session" do
    let(:post_binding) { Saml::Kit::Bindings::HttpPost.new(location: "/session/logout") }
    let(:user) { create(:user) }

    context "when receiving a logout request" do
      let(:session_id) { session_id_from(response) }

      before do
        http_login(user)
        session_id

        allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
        builder = Saml::Kit::LogoutRequest.builder(user) do |x|
          x.issuer = issuer
          x.embed_signature = false
        end
        url, saml_params = post_binding.serialize(builder)
        post url, params: saml_params
        follow_redirect!
      end

      specify { expect(response).to have_http_status(:ok) }
      specify { expect(response.body).to include("SAMLResponse") }
      specify { expect(response.body).to include(sp_metadata.single_logout_service_for(binding: :http_post).location) }
      specify { expect(session_id_from(response)).to be_present }
      specify { expect(session_id_from(response)).not_to eql(session_id) }
    end

    context "when receiving a logout response" do
      before do
        allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
        builder = Saml::Kit::LogoutResponse.builder(Saml::Kit::AuthenticationRequest.build) do |x|
          x.issuer = issuer
          x.embed_signature = false
        end
        url, saml_params = post_binding.serialize(builder)
        post url, params: saml_params
      end

      specify { expect(response).to redirect_to(new_session_url) }
    end

    context "when logging out of the IDP only" do
      let(:user) { create(:user) }
      let(:session_id) { session_id_from(response) }

      before do
        http_login(user)
        session_id
        delete session_path
      end

      specify { expect(session_id_from(response)).not_to eql(session_id) }
      specify { expect(session_id_from(response)).to be_present }
      specify { expect(response).to redirect_to(new_session_path) }
    end
  end
end
