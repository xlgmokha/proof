# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserSession do
  subject { build(:user_session) }

  describe "#revoke!" do
    before { subject.revoke! }

    specify { expect(subject.revoked_at).to be_present }
  end

  describe "#access" do
    subject { create(:user_session) }

    let(:request) { instance_double(ActionDispatch::Request, ip: "192.168.1.1", user_agent: "blah") }
    let(:result) { subject.access(request) }

    before do
      freeze_time
      result
    end

    specify { expect(subject.accessed_at).to eql(Time.current) }
    specify { expect(subject.ip).to eql(request.ip) }
    specify { expect(subject.user_agent).to eql(request.user_agent) }
    specify { expect(subject).to be_persisted }
    specify { expect(result).to eql(subject.key) }
  end

  describe ".active" do
    let!(:active_session) { create(:user_session) }
    let!(:inactive_session) { create(:user_session, :idle_timeout_expired) }
    let!(:expired_session) { create(:user_session, :absolute_timeout_expired) }
    let!(:revoked_session) { create(:user_session, :revoked) }

    specify { expect(described_class.active).to match_array([active_session]) }
    specify { expect(described_class.revoked).to match_array([revoked_session]) }
    specify { expect(described_class.expired).to match_array([inactive_session, expired_session]) }
    specify { expect(described_class.idle_timeout).to match_array([inactive_session]) }
    specify { expect(described_class.absolute_timeout).to match_array([expired_session]) }
  end

  describe ".authenticate" do
    let!(:active_session) { create(:user_session) }
    let!(:inactive_session) { create(:user_session, :idle_timeout_expired) }
    let!(:expired_session) { create(:user_session, :absolute_timeout_expired) }
    let!(:revoked_session) { create(:user_session, :revoked) }

    specify { expect(described_class.authenticate(active_session.key)).to eql(active_session) }
    specify { expect(described_class.authenticate("blah")).to be_nil }
    specify { expect(described_class.authenticate(inactive_session.key)).to be_nil }
    specify { expect(described_class.authenticate(expired_session.key)).to be_nil }
    specify { expect(described_class.authenticate(revoked_session.key)).to be_nil }
    specify { expect(described_class.authenticate(nil)).to be_nil }
    specify { expect(described_class.authenticate("")).to be_nil }
  end

  describe ".sudo?" do
    let!(:sudo_session) { create(:user_session, :sudo) }
    let!(:non_sudo_session) { create(:user_session) }

    specify { expect(sudo_session).to be_sudo }
    specify { expect(non_sudo_session).not_to be_sudo }
  end
end
