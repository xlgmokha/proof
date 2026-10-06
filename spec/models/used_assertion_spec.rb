# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsedAssertion do
  let(:client) { create(:client) }

  describe '.redeem!' do
    it 'accepts an assertion the first time' do
      expect(described_class.redeem!(client, 'abc', 5.minutes.from_now)).to be(true)
    end

    it 'rejects the same jti for the same client' do
      described_class.redeem!(client, 'abc', 5.minutes.from_now)

      expect(described_class.redeem!(client, 'abc', 5.minutes.from_now)).to be(false)
    end

    it 'accepts the same jti from another client' do
      described_class.redeem!(client, 'abc', 5.minutes.from_now)

      expect(described_class.redeem!(create(:client), 'abc', 5.minutes.from_now)).to be(true)
    end

    it 'forgets expired assertions' do
      described_class.create!(client: client, jti: 'old', expires_at: 1.minute.ago)
      described_class.redeem!(client, 'abc', 5.minutes.from_now)

      expect(described_class.where(jti: 'old')).not_to exist
    end
  end
end
