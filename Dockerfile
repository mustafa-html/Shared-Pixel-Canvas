# Production image: the React client is built and copied into Rails' public/
# directory, so one container serves the page, the API and the WebSocket from
# a single origin.
FROM node:22-slim AS client
WORKDIR /client
COPY client/package.json client/package-lock.json ./
RUN npm ci
COPY client/ ./
RUN npm run build

FROM ruby:3.3-slim
ENV RAILS_ENV=production \
    BUNDLE_WITHOUT="development:test"

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends build-essential default-libmysqlclient-dev libyaml-dev pkg-config git curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY api/Gemfile api/Gemfile.lock* ./
RUN bundle install

COPY api/ ./
COPY --from=client /client/dist ./public

EXPOSE 3000
CMD ["sh", "-c", "bundle exec rails db:prepare && bundle exec rake board:ensure && bundle exec puma -C config/puma.rb"]
