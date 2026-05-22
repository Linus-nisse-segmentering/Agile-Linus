# Use Ruby 3.2 as base image
FROM ruby:3.2-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    sqlite3 \
    libpq-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock* ./

# Install Ruby dependencies
# Lower parallelism and bump retries to avoid transient network EOFs.
RUN bundle config set --local without 'development' && \
    bundle config set --local retry 5 && \
    bundle config set --local jobs 1 && \
    BUNDLE_GEM__HTTP__PERSISTENT=1 bundle install

# Copy application files
COPY app.rb .
COPY config.ru .
COPY yml/ ./yml/
COPY db/ ./db/
COPY static/ ./static/
COPY views/ ./views/

# Expose port
EXPOSE 1010

# Set environment variables
ENV RACK_ENV=production

# Run the application with Puma
CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:1010"]
