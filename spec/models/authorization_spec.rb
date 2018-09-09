require 'rails_helper'

RSpec.describe Authorization, type: :model do
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
