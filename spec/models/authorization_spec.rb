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
end
