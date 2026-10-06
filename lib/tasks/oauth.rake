# frozen_string_literal: true

namespace :oauth do
  desc 'Delete replay-protection records that can no longer matter'
  task purge: :environment do
    puts "Deleted #{UsedAssertion.purge_expired!} expired assertions"
    puts "Deleted #{UsedProof.purge_expired!} expired proofs"
    puts "Deleted #{PushedAuthorizationRequest.purge_expired!} expired pushed requests"
    puts "Deleted #{DeviceAuthorization.purge_expired!} expired device authorizations"
  end
end
