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
    name = Rails.application.class.name.split(':')[0].downcase
    Rake::PackageTask.new(name, build) do |package|
      package.need_tar_gz = true
      package.package_files.add INCLUDED_FILES
      package.package_files.exclude EXCLUDED_FILES
    end
    Rake::Task['repackage'].invoke
  end
end
