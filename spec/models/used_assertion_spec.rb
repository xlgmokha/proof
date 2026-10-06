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

    it 'accepts a jti again once its earlier use has expired' do
      described_class.create!(client: client, jti: 'old', expires_at: 1.minute.ago)

      expect(described_class.redeem!(client, 'old', 5.minutes.from_now)).to be(true)
    end

    # On PostgreSQL a unique violation aborts the enclosing transaction.
    it 'reports a replay inside a transaction without aborting it' do
      described_class.redeem!(client, 'abc', 5.minutes.from_now)

      described_class.transaction do
        expect(described_class.redeem!(client, 'abc', 5.minutes.from_now)).to be(false)
        expect(described_class.count).to be(1)
      end
    end

    it 'does not purge unrelated records on the request path' do
      described_class.create!(client: client, jti: 'old', expires_at: 1.minute.ago)
      described_class.redeem!(client, 'abc', 5.minutes.from_now)

      expect(described_class.where(jti: 'old')).to exist
    end
  end

  describe '.purge_expired!' do
    it 'forgets expired assertions only' do
      described_class.create!(client: client, jti: 'old', expires_at: 1.minute.ago)
      described_class.create!(client: client, jti: 'new', expires_at: 1.minute.from_now)

      described_class.purge_expired!

      expect(described_class.pluck(:jti)).to eql(['new'])
    end
  end
end
