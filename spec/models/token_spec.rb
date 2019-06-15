# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Token, type: :model do
  describe "revoke!" do
    subject { create(:access_token) }

    context "when the token has not been revoked yet" do
      before do
        freeze_time
        subject.revoke!
      end

      specify { expect(subject.reload.revoked_at.to_i).to eql(Time.current.to_i) }
    end

    context "when a token associated with an authorization grant is revoked" do
      subject { create(:access_token, authorization: authorization) }

      let(:authorization) { create(:authorization) }
      let!(:other_token) { create(:access_token, authorization: authorization) }

      before { subject.revoke! }

      specify { expect(authorization.reload).to be_revoked }
      specify { expect(other_token.reload).to be_revoked }
    end
  end

  describe ".expired" do
    let!(:active_token) { create(:access_token) }
    let!(:expired_token) { create(:access_token, expired_at: 1.second.ago) }

    specify { expect(Token.expired).to match_array([expired_token]) }
  end

  describe ".revoked" do
    let!(:revoked_token) { create(:access_token, revoked_at: 1.second.ago) }
    let!(:active_token) { create(:access_token) }

    specify { expect(Token.revoked).to match_array([revoked_token]) }
  end

  describe ".claims_for" do
    subject { described_class }

    let(:access_token) { build_stubbed(:access_token).to_jwt }
    let(:refresh_token) { build_stubbed(:refresh_token).to_jwt }

    specify { expect(subject.claims_for('blah', token_type: :access)).to be_empty }
    specify { expect(subject.claims_for('blah', token_type: :refresh)).to be_empty }
    specify { expect(subject.claims_for('blah', token_type: :any)).to be_empty }
    specify { expect(subject.claims_for(access_token, token_type: :access)).to be_present }
    specify { expect(subject.claims_for(refresh_token, token_type: :refresh)).to be_present }
  end

  describe ".authenticate" do
    subject { described_class }

    context "when the access_token is active" do
      let(:token) { create(:access_token) }

      specify { expect(subject.authenticate(token.to_jwt)).to eql(token) }
    end

    context "when the token is a refresh token" do
      let(:token) { create(:refresh_token) }

      specify { expect(subject.authenticate(token.to_jwt)).to be_nil }
    end

    context "when the access token has been revoked" do
      let(:token) { create(:access_token, :revoked) }

      specify { expect(subject.authenticate(token.to_jwt)).to be_nil }
    end

    context "when the access token is expired" do
      let(:token) { create(:access_token, :expired) }

      specify { expect(subject.authenticate(token.to_jwt)).to be_nil }
    end
  end
end
