# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Authorization, type: :model do
  describe '#valid_verifier?' do
    # RFC 7636 Appendix B
    let(:verifier) { 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk' }
    let(:challenge) { 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM' }

    context 'when the challenge method is S256' do
      subject { build(:authorization, challenge: challenge, challenge_method: :sha256) }

      specify { expect(subject).to be_valid_verifier(verifier) }
      specify { expect(subject).not_to be_valid_verifier('invalid') }
      specify { expect(subject).not_to be_valid_verifier(nil) }
    end

    context 'when the challenge method is plain' do
      subject { build(:authorization, challenge: verifier, challenge_method: :plain) }

      specify { expect(subject).to be_valid_verifier(verifier) }
      specify { expect(subject).not_to be_valid_verifier('invalid') }
    end

    context 'when there is no challenge' do
      subject { build(:authorization, challenge: nil) }

      specify { expect(subject).to be_valid_verifier(nil) }
    end
  end

  describe '#revoke!' do
    subject { create(:authorization) }

    context "when the authorization has not been revoked" do
      before { subject.revoke! }

      specify { expect(subject.revoked_at).to be_present }
    end

    context "when the authorization has already been revoked" do
      before { subject.revoke! }

      specify do
        expect do
          subject.revoke!
        end.to raise_error(/already revoked/)
      end
    end
  end

  describe ".active, .revoked, .expired" do
    subject { described_class }

    let!(:active) { create(:authorization) }
    let!(:expired) { create(:authorization, expired_at: 1.second.ago) }
    let!(:revoked) { create(:authorization, revoked_at: 1.second.ago) }

    specify { expect(subject.active).to match_array([active]) }
    specify { expect(subject.expired).to match_array([expired]) }
    specify { expect(subject.revoked).to match_array([revoked]) }
  end
end
