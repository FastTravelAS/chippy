FROM ruby:3.2.1-slim-buster as base

# Set the working directory
WORKDIR /app

# Copy the application files into the container
COPY . .

# Set production environment
ENV RUBY_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

FROM base as build

COPY Gemfile Gemfile.lock ./
RUN bundle install \
    && rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy application code
COPY . .

# Make sure the bin/start script is executable
RUN chmod +x bin/start

FROM base

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

# Add application user
RUN useradd chippy --home /app --shell /bin/bash
USER chippy:chippy

# Set the entry point for the container
ENTRYPOINT ["bin/start"]
