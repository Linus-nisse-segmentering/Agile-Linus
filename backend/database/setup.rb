#!/usr/bin/env ruby
# frozen_string_literal: true

# Database setup script for Recipe Cookbook

require 'sqlite3'
require 'fileutils'

# Configuration
DB_DIR = File.dirname(__FILE__)
DB_FILE = File.join(DB_DIR, '..', 'app.db')
SCHEMA_FILE = File.join(DB_DIR, 'schema.sql')
SEEDS_FILE = File.join(DB_DIR, 'seeds.sql')

def setup_database
  puts 'Setting up database...'

  # Remove existing database if it exists
  if File.exist?(DB_FILE)
    puts 'Removing existing database...'
    File.delete(DB_FILE)
  end

  # Create new database
  db = SQLite3::Database.new(DB_FILE)

  # Run schema
  puts 'Creating tables...'
  schema_sql = File.read(SCHEMA_FILE)
  db.execute_batch(schema_sql)

  # Run seeds
  puts 'Seeding data...'
  seeds_sql = File.read(SEEDS_FILE)
  db.execute_batch(seeds_sql)

  db.close

  puts 'Database setup complete!'
  puts "Database location: #{DB_FILE}"
end

# Run setup if this file is executed directly
setup_database if __FILE__ == $PROGRAM_NAME
