# frozen_string_literal: true

class Package
  INCLUDED_FILES = [
    ".ruby-version",
    "BUILD",
    "Dockerfile",
    "Gemfile*",
    "Procfile",
    "Rakefile",
    "app/**/*",
    "bin/*",
    "config.ru",
    "config/**/*",
    "db/**/*",
    "lib/**/*",
    "public/**/*",
    "public/assets/.sprockets*",
    "vendor/cache/**/*"
  ].freeze

  EXCLUDED_FILES = [
    "config/database.yml",
    "db/*.sqlite3",
    /public\/packs-test/,
  ].freeze

  def self.execute
    require 'rake/packagetask'

    build = `git rev-parse --short HEAD`.strip
    IO.write("./BUILD", build)
    Rake::PackageTask.new("proof", build) do |package|
      package.need_tar_gz = true
      package.package_files.add INCLUDED_FILES
      package.package_files.exclude EXCLUDED_FILES
      #package.package_files.exclude { |path| path.start_with?(*EXCLUDED_FILES) }
    end
    Rake::Task['repackage'].invoke
  end
end
