# frozen_string_literal: true

# This is a temporary workaround until there is a patch for CVE-2018-1000544
# https://github.com/rubyzip/rubyzip/issues/369
namespace :bundle do
  desc 'Updates the ruby-advisory-db then runs bundle-audit'
  task :audit do
    require 'bundler/audit/cli'

    Bundler::Audit::CLI.start ['update']
    Bundler::Audit::CLI.start ['check', '--ignore', 'CVE-2018-1000544']
  end
end

namespace :lint do
  begin
    require 'rubocop/rake_task'
    require 'bundler/audit/task'

    RuboCop::RakeTask.new
    # Bundler::Audit::Task.new
  rescue LoadError => error
    puts error.message
  end

  desc "run the brakeman vulnerability scanner"
  task :brakeman do
    require 'brakeman'
    Brakeman.run(
      app_path: Rails.root,
      print_report: true,
      pager: false,
      config_file: Rails.root.join("config", "brakeman"),
    )
  end

  desc "run eslint"
  task(:eslint) { sh 'yarn lint' }

  desc "Run linters to check the quality of the code."
  task all: [:rubocop, 'bundle:audit', :brakeman, :eslint]
end
