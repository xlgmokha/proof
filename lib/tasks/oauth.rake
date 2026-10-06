# frozen_string_literal: true

namespace :oauth do
  desc 'Delete replay-protection records that can no longer matter'
  task purge: :environment do
    puts "Deleted #{UsedAssertion.purge_expired!} expired assertions"
  end
end
