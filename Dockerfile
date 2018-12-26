FROM ruby:2.6-alpine
ENV RAILS_ENV production
ENV RAILS_LOG_TO_STDOUT true
ENV RAILS_SERVE_STATIC_FILES true
ENV PACKAGES build-base libxml2-dev tzdata postgresql-dev
ADD *.tar.gz .
RUN ln -s /proof-* /app
WORKDIR /app
RUN apk update && \
    apk upgrade && \
    apk add $PACKAGES && \
    rm -fr /var/cache/apk/* && \
    bundle install --deployment --without development doc test --jobs "$(nproc)" --local && \
    apk del build-base && \
    rm -fr vendor/cache
RUN adduser -D -u 1000 rails && chown -R rails:rails /app/
USER rails
ENTRYPOINT ["bundle", "exec"]
CMD ["foreman", "start"]
