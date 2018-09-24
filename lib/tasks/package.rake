# frozen_string_literal: true

namespace :package do
  desc "create a tarball"
  task tarball: ['webpacker:clobber', 'webpacker:compile', 'doc:build'] do
    require 'package'
    Package.execute
  end
end
