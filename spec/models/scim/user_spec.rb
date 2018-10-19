# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SCIM::User do
  describe "#valid?" do
    specify { expect(build(:scim_user)).to be_valid }
    specify { expect(build(:scim_user, id: 1)).to be_invalid }

    specify do
      subject = build(:scim_user, schemas: ["urn:ietf:params:scim:schemas:core:2.0:Blah"])
      expect(subject).not_to be_valid
      expect(subject.errors[:schemas]).to be_present
    end

    specify do
      subject = build(:scim_user, userName: nil)
      expect(subject).not_to be_valid
      expect(subject.errors[:userName]).to be_present
    end

    specify do
      subject = build(:scim_user, userName: 'notanemail')
      expect(subject).not_to be_valid
      expect(subject.errors[:userName]).to be_present
    end

    specify do
      subject = build(:scim_user, locale: '')
      expect(subject).not_to be_valid
      expect(subject.errors[:locale]).to be_present
    end

    specify do
      subject = build(:scim_user, locale: 'de')
      expect(subject).not_to be_valid
      expect(subject.errors[:locale]).to be_present
    end

    specify do
      subject = build(:scim_user, timezone: '')
      expect(subject).not_to be_valid
      expect(subject.errors[:timezone]).to be_present
    end

    specify do
      subject = build(:scim_user, timezone: 'etc/unknown')
      expect(subject).not_to be_valid
      expect(subject.errors[:timezone]).to be_present
    end
  end

  describe "#save!" do
    context "when the user is new" do
      let(:current_user) { create(:user) }

      before { allow(Current).to receive(:user).and_return(current_user) }

      context "when creating a user" do
        subject { build(:scim_user) }

        specify { expect(subject.save!).to be_persisted }
        specify { expect(subject.save!.uuid).to be_present }
        specify { expect(subject.save!.email).to eql(subject.userName) }
        specify { expect(subject.save!.locale).to eql(subject.locale) }
        specify { expect(subject.save!.timezone).to eql(subject.timezone) }
        specify { expect(subject.save!.password_digest).to be_present }
      end
    end

    context "when one user is updating another user" do
      subject { build(:scim_user, id: other_user.to_param) }

      let(:current_user) { create(:user) }
      let(:other_user) { create(:user) }

      before { allow(Current).to receive(:user).and_return(current_user) }

      specify { expect(subject.save!.uuid).to eql(other_user.uuid) }
      specify { expect(subject.save!.email).to eql(subject.userName) }
      specify { expect(subject.save!.locale).to eql(subject.locale) }
      specify { expect(subject.save!.timezone).to eql(subject.timezone) }
    end

    context "when one user attempts to change the password of another user" do
      subject { build(:scim_user, id: other_user.to_param, password: generate(:password)) }

      let(:current_user) { create(:user) }
      let(:other_user) { create(:user) }

      before { allow(Current).to receive(:user).and_return(current_user) }

      specify { expect { subject.save! }.to raise_error(StandardError) }
    end

    context "when a user changes their own password" do
      subject { build(:scim_user, id: current_user.to_param, password: password) }

      let!(:current_user) { create(:user) }
      let(:password) { generate(:password) }

      before do
        freeze_time
        allow(Current).to receive(:user).and_return(current_user)
      end

      specify { expect(subject.save!.authenticate(password)).to be_truthy }
    end
  end

  describe "#humanAttributeName" do
    subject { described_class }

    specify { expect(subject.human_attribute_name('userName')).to eql('userName') }
    specify { expect(subject.human_attribute_name('schemas')).to eql('schemas') }
    specify { expect(subject.human_attribute_name('locale')).to eql('locale') }
    specify { expect(subject.human_attribute_name('password')).to eql('password') }
  end
end
