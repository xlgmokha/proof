FROM ruby:2.5.3-alpine
ENV RAILS_ENV production
ENV RAILS_LOG_TO_STDOUT true
ENV RAILS_SERVE_STATIC_FILES true
ENV PACKAGES build-base libxml2-dev tzdata postgresql-dev
RUN apk update && apk upgrade && apk add $PACKAGES && rm -fr /var/cache/apk/*
ADD *.tar.gz .
RUN ln -s /proof-* /app
WORKDIR /app
RUN bundle install --deployment --jobs "$(nproc)" --local
RUN apk del build-base
RUN adduser -D -u 1000 rails && chown -R rails:rails /app/
USER rails
ENTRYPOINT ["bundle", "exec"]
CMD ["foreman", "start"]
