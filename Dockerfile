FROM ruby:2.5
ENV RAILS_ENV production
RUN useradd rails
ADD *.tar.gz .
RUN ln -s /proof-* /app && chown -R rails:rails /app/
WORKDIR /app
RUN bundle install --without development test --jobs "$(nproc)" --quiet # --local
USER rails
ENTRYPOINT ["bundle", "exec"]
CMD ["foreman", "start"]
