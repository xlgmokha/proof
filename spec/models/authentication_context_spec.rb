# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuthenticationContext do
  let(:user) { create(:user) }
  let(:session_record) { user.sessions.create!(created_at: 3.minutes.ago) }

  describe '.for' do
    specify { expect(described_class.for(session_record, nil, user).acr).to eql(described_class::PASSWORD) }
    specify { expect(described_class.for(session_record, nil, user).auth_time).to eql(session_record.created_at.to_i) }

    it 'is the MFA class once a one time code was entered' do
      allow_any_instance_of(Mfa).to receive(:setup?).and_return(true)
      issued = 1.minute.ago.to_i
      context = described_class.for(session_record, { 'issued_at' => issued }, user)
      expect(context.acr).to eql(described_class::MFA)
      expect(context.auth_time).to eql(issued)
    end
  end

  describe '#satisfies?' do
    specify { expect(described_class.new(described_class::MFA, 0).satisfies?(described_class::PASSWORD)).to be(true) }
    specify { expect(described_class.new(described_class::PASSWORD, 0).satisfies?(described_class::MFA)).to be(false) }
    specify { expect(described_class.new(described_class::PASSWORD, 0).satisfies?("unknown #{described_class::PASSWORD}")).to be(true) }
    specify { expect(described_class.new(described_class::PASSWORD, 0).satisfies?('unknown')).to be(false) }
    specify { expect(described_class.new(described_class::PASSWORD, 0).satisfies?(nil)).to be(true) }
  end

  describe '#older_than?' do
    specify { expect(described_class.new('x', 10.seconds.ago.to_i).older_than?('60')).to be(false) }
    specify { expect(described_class.new('x', 2.minutes.ago.to_i).older_than?('60')).to be(true) }
    specify { expect(described_class.new('x', 2.minutes.ago.to_i).older_than?(nil)).to be(false) }
  end
end
