# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "/response" do
  describe 'GET /response' do
    context "when the user has not completed password authentication" do
      before { get '/response' }

      specify { expect(response).to redirect_to(new_session_path) }
    end

    context "when the user has completed password authentication" do
      let(:current_user) { create(:user) }

      before { http_login(current_user, skip_mfa: true) }

      context "when a saml request was present in session" do
        let(:registry) { Saml::Kit::DefaultRegistry.new }
        let(:issuer) { Saml::Kit.configuration.entity_id }
        let(:redirect_binding) { Saml::Kit::Bindings::HttpRedirect.new(location: new_session_url) }
        let(:relay_state) { SecureRandom.uuid }
        let(:sp_metadata) do
          Saml::Kit::ServiceProviderMetadata.build do |x|
            x.add_assertion_consumer_service(FFaker::Internet.uri("https"), binding: :http_post)
            x.add_single_logout_service(FFaker::Internet.uri("https"), binding: :http_post)
          end
        end

        before do
          Saml::Kit.configuration.registry = registry
          allow(registry).to receive(:metadata_for).with(issuer).and_return(sp_metadata)
          get redirect_binding.serialize(Saml::Kit::AuthenticationRequest.builder, relay_state: relay_state)[0]
        end

        context "when the saml request is still valid" do
          before { get '/response' }

          specify { expect(response).to have_http_status(:ok) }
          specify { expect(response.body).to include(sp_metadata.assertion_consumer_service_for(binding: :http_post).location) }
          specify { expect(response.body).to include('SAMLResponse') }
          specify { expect(response.body).to include('RelayState') }
          specify { expect(response.body).to include(relay_state) }
        end

        context "when the SAML request is no longer valid" do
          before do
            allow(registry).to receive(:metadata_for).with(issuer).and_return(nil)
            get '/response'
          end

          specify { expect(response).to have_http_status(:forbidden) }
        end
      end

      context "when a saml request was not present in session" do
        before { get '/response' }

        specify { expect(response).to redirect_to(my_dashboard_path) }
      end

      context "when MFA authentication has not been completed" do
        let(:current_user) { create(:user, :mfa_configured) }

        before { get '/response' }

        specify { expect(response).to redirect_to(new_mfa_path) }
      end
    end
  end
end
