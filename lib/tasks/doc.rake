# frozen_string_literal: true

namespace :doc do
  desc "Build static pages"
  task build: [:clean] do
    sh "jekyll b --config config/jekyll.yml"
  end

  desc "Watch and rebuild static pages"
  task :watch do
    sh "jekyll b --config config/jekyll.yml --watch"
  end

  desc "Clean up after Jekyll"
  task :clean do
    sh "rm -fr public/doc"
    sh "mkdir public/doc && touch public/doc/.keep"
  end
end
