# Use Ruby 3.2 as base image
FROM ruby:3.2-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    sqlite3 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock* ./

# Install Ruby dependencies
RUN bundle config set --local without 'development' && \
    bundle install --jobs 4 --retry 3

# Copy application files
COPY app.rb .
COPY config.ru .
COPY api-schema.yaml .
COPY db/ ./db/
COPY static/ ./static/
COPY views/ ./views/

# Expose port
EXPOSE 3000

# Set environment variables
ENV RACK_ENV=production

# Run the application with Puma
CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:3000"]
