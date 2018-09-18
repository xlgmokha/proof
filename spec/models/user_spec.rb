require 'rails_helper'

RSpec.describe User do
  describe ".authenticate_token" do
    subject { described_class }

    context "when the access_token is active" do
      let(:token) { create(:access_token) }

      specify { expect(subject.authenticate_token(token.to_jwt)).to eql(token.subject) }
    end

    context "when the token is a refresh token" do
      let(:token) { create(:refresh_token) }

      specify { expect(subject.authenticate_token(token.to_jwt)).to be_nil }
    end

    context "when the access token has been revoked" do
      let(:token) { create(:access_token, :revoked) }

      specify { expect(subject.authenticate_token(token.to_jwt)).to be_nil }
    end

    context "when the access token is expired" do
      let(:token) { create(:access_token, :expired) }

      specify { expect(subject.authenticate_token(token.to_jwt)).to be_nil }
    end
  end
end
