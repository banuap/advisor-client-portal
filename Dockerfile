FROM ruby:3.3-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
RUN SECRET_KEY_BASE=build-only-key bundle exec rails db:prepare \
    && SECRET_KEY_BASE=build-only-key bundle exec rails test

FROM ruby:3.3-slim
RUN apt-get update && apt-get install -y --no-install-recommends libpq5 libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app/Gemfile /app/Gemfile
COPY --from=build /app/Gemfile.lock /app/Gemfile.lock
COPY --from=build /app/config /app/config
COPY --from=build /app/db /app/db
COPY --from=build /app/app /app/app
COPY --from=build /app/config.ru /app/config.ru
COPY --from=build /app/Rakefile /app/Rakefile
RUN mkdir -p /app/storage /app/log /app/tmp && chown -R 10001:0 /app
ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=true
ENV PORT=3000
EXPOSE 3000
USER 10001
ENTRYPOINT ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
