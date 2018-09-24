# frozen_string_literal: true

namespace :package do
  desc "create a tarball"
  task tarball: ['assets:clobber', 'assets:precompile'] do
    require 'package'
    Package.execute
  end
end
