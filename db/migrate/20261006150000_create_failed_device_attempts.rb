# frozen_string_literal: true

# RFC 8628 Section 5.1: user codes are guessable, so failed entries are
# counted and further guesses are refused.
class CreateFailedDeviceAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :failed_device_attempts do |t|
      t.string :subject, null: false
      t.datetime :created_at, null: false
    end
    add_index :failed_device_attempts, %i[subject created_at]
    add_index :failed_device_attempts, :created_at
  end
end
