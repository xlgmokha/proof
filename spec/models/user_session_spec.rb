require 'rails_helper'

RSpec.describe UserSession do
  subject { build(:user_session) }

  describe "#revoke!" do
    before { subject.revoke! }

    specify { expect(subject.revoked_at).to be_present }
  end

  describe "#access" do
    subject { create(:user_session) }
    let!(:original_key) { subject.key }
    let(:request) { double(ip: "192.168.1.1", user_agent: "blah") }

    before { freeze_time }
    before { subject.access(request) }

    specify { expect(subject.accessed_at).to eql(Time.now) }
    specify { expect(subject.ip).to eql(request.ip) }
    specify { expect(subject.user_agent).to eql(request.user_agent) }
    specify { expect(subject).to be_persisted }
    specify { expect(subject.key).not_to eql(original_key) }
  end

  describe ".active" do
    let!(:active_session) { create(:user_session) }
    let!(:inactive_session) { create(:user_session, :idle_timeout_expired) }
    let!(:expired_session) { create(:user_session, :absolute_timeout_expired) }
    let!(:revoked_session) { create(:user_session, :revoked) }

    specify { expect(UserSession.active).to match_array([active_session]) }
    specify { expect(UserSession.revoked).to match_array([revoked_session]) }
    specify { expect(UserSession.expired).to match_array([inactive_session, expired_session]) }
    specify { expect(UserSession.idle_timeout).to match_array([inactive_session]) }
    specify { expect(UserSession.absolute_timeout).to match_array([expired_session]) }
  end

  describe ".authenticate" do
    let!(:active_session) { create(:user_session) }
    let!(:inactive_session) { create(:user_session, :idle_timeout_expired) }
    let!(:expired_session) { create(:user_session, :absolute_timeout_expired) }
    let!(:revoked_session) { create(:user_session, :revoked) }

    specify { expect(UserSession.authenticate(active_session.key)).to eql(active_session) }
    specify { expect(UserSession.authenticate("blah")).to be_nil }
    specify { expect(UserSession.authenticate(inactive_session.key)).to be_nil }
    specify { expect(UserSession.authenticate(expired_session.key)).to be_nil }
    specify { expect(UserSession.authenticate(revoked_session.key)).to be_nil }
  end

  describe ".sudo?" do
    let!(:sudo_session) { create(:user_session, :sudo) }
    let!(:non_sudo_session) { create(:user_session) }

    specify { expect(sudo_session).to be_sudo }
    specify { expect(non_sudo_session).not_to be_sudo }
  end
end
