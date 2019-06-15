# frozen_string_literal: true

namespace :doc do
  Bundler.require(:doc)

  def default_options
    {
      config: Rails.root.join("config", "jekyll.yml").to_s,
      source: Rails.root.join('doc').to_s,
      destination: Rails.root.join('public', 'doc').to_s
    }
  end

  desc 'Clean the API documentation'
  task :clean do
    rm_rf Rails.root.join('public', 'doc')
  end

  desc "Build static pages"
  task build: [:clean, :environment] do
    Jekyll::Site.new(Jekyll.configuration(default_options)).process
  end

  desc "Watch and rebuild static pages"
  task watch: [:clean, :environment] do
    custom_options = default_options.merge(watch: true)
    Jekyll::Commands::Build.process(custom_options)
  end
end
