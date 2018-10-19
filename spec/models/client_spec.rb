# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Client do
  describe "#validation" do
    specify { expect(build(:client)).to be_valid }
    specify { expect(build(:client, redirect_uri: nil)).to be_invalid }
    specify { expect(build(:client, redirect_uri: '<script>alert("hi")</script>')).to be_invalid }
    specify { expect(build(:client, redirect_uri: 'invalid')).to be_invalid }
    specify { expect(build(:client, uuid: nil)).to be_invalid }
    specify { expect(build(:client, uuid: 'invalid')).to be_invalid }
    specify { expect(build(:client, name: nil)).to be_invalid }
  end

  describe "#redirect_url" do
    subject { build(:client) }

    let(:code) { SecureRandom.uuid }
    let(:redirect_uri) { subject.redirect_uri }

    specify { expect(subject.redirect_url(code: code)).to eql("#{redirect_uri}#code=#{code}") }
    specify { expect { subject.redirect_url(state: '<script>alert("hi");</script>') }.to raise_error(URI::InvalidURIError) }
  end
end
