require 'rails_helper'

RSpec.describe Authentication do
  describe PasswordAuthentication do
    describe "#authenticate" do
      subject { create(:password_authentication, user: user) }
      let(:user) { create(:user, password: password) }
      let(:password) { generate(:password) }
      let(:invalid) { SecureRandom.hex(20) }

      specify { expect(subject.authenticate(password)).to eql(user) }
      specify { expect(subject.authenticate(invalid)).to be(false) }
    end
  end

  describe TotpAuthentication do
    describe "#authenticate" do
      subject { create(:totp_authentication, user: user) }
      let(:user) { create(:user, :mfa_configured) }
      let(:current_totp) { ROTP::TOTP.new(user.mfa_secret).now }
      let(:invalid_totp) { rand(99_999).to_s }

      before { freeze_time }

      specify { expect(subject.authenticate(current_totp)).to eql(user) }
      specify { expect(subject.authenticate(invalid_totp)).to be(false) }
    end
  end
end
