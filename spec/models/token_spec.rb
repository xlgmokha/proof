require 'rails_helper'

RSpec.describe Token, type: :model do
  describe "revoke!" do
    subject { create(:access_token) }

    context "when the token has not been revoked yet" do
      before { freeze_time }
      before { subject.revoke! }

      specify { expect(subject.reload.revoked_at.to_i).to eql(DateTime.now.to_i) }
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
end
