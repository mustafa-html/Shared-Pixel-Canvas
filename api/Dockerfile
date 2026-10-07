# Development image. The source is mounted over /app by docker-compose.yml,
# so only the gems are baked in.
FROM ruby:3.3-slim

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends build-essential default-libmysqlclient-dev libyaml-dev pkg-config git curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
