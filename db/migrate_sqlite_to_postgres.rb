#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sqlite3'
require 'pg'

DB_DIR = File.dirname(__FILE__)
DEFAULT_SQLITE_PATH = File.join(DB_DIR, '..', 'app.db')
SCHEMA_FILE = File.join(DB_DIR, 'schema.pg.sql')

SQLITE_PATH = ENV.fetch('SQLITE_PATH', DEFAULT_SQLITE_PATH)
DB_HOST = ENV.fetch('DB_HOST', 'localhost')
DB_PORT = Integer(ENV.fetch('DB_PORT', '5432'))
DB_NAME = ENV.fetch('DB_NAME', 'recipe_cookbook')
DB_USER = ENV.fetch('DB_USER', 'recipe_user')
DB_PASSWORD = ENV.fetch('DB_PASSWORD', 'recipe_pass')
DB_SSLMODE = ENV.fetch('DB_SSLMODE', 'prefer')
PG_CLEAR = ENV.fetch('PG_CLEAR', 'false').downcase == 'true'

TABLES = [
  %w[users id email password name],
  %w[recipes id title time_minutes price link description image],
  %w[ingredients id name],
  %w[tags id name],
  %w[recipe_ingredients recipe_id ingredient_id amount unit],
  %w[recipe_tags recipe_id tag_id],
].freeze

SEQUENCE_TABLES = %w[users recipes ingredients tags].freeze

def row_to_hash(row)
  return {} if row.nil?

  row.reject { |key, _value| key.is_a?(Integer) }
end

def pg_connection
  if ENV['DATABASE_URL'] && !ENV['DATABASE_URL'].empty?
    PG.connect(ENV['DATABASE_URL'])
  else
    PG.connect(
      host: DB_HOST,
      port: DB_PORT,
      dbname: DB_NAME,
      user: DB_USER,
      password: DB_PASSWORD,
      sslmode: DB_SSLMODE,
    )
  end
end

def ensure_schema(pg_conn)
  pg_conn.exec(File.read(SCHEMA_FILE))
end

def table_count(pg_conn, table_name)
  pg_conn.exec_params("SELECT COUNT(*) FROM #{table_name}", []).getvalue(0, 0).to_i
end

def clear_tables(pg_conn)
  pg_conn.exec(<<~SQL)
    TRUNCATE TABLE recipe_tags, recipe_ingredients, recipes, ingredients, tags, users
    RESTART IDENTITY CASCADE
  SQL
end

def set_sequence(pg_conn, table_name)
  sequence_name = pg_conn.exec_params('SELECT pg_get_serial_sequence($1, $2)', [table_name, 'id']).getvalue(0, 0)
  max_id = pg_conn.exec_params("SELECT MAX(id) FROM #{table_name}", []).getvalue(0, 0)

  if max_id.nil?
    pg_conn.exec_params('SELECT setval($1, 1, false)', [sequence_name])
  else
    pg_conn.exec_params('SELECT setval($1, $2, true)', [sequence_name, max_id.to_i])
  end
end

puts "Migrating SQLite data from #{SQLITE_PATH} to PostgreSQL #{DB_HOST}:#{DB_PORT}/#{DB_NAME}"

unless File.exist?(SQLITE_PATH)
  warn "SQLite database not found at #{SQLITE_PATH}"
  exit 1
end

sqlite = SQLite3::Database.new(SQLITE_PATH)
sqlite.results_as_hash = true

pg = pg_connection

ensure_schema(pg)

existing_counts = TABLES.to_h { |table, *_cols| [table, table_count(pg, table)] }
if existing_counts.values.any?(&:positive?) && !PG_CLEAR
  warn 'PostgreSQL database is not empty. Set PG_CLEAR=true to truncate before migrating.'
  existing_counts.each { |table, count| warn "#{table}: #{count} rows" }
  exit 1
end

clear_tables(pg) if PG_CLEAR

pg.transaction do |conn|
  TABLES.each do |table, *columns|
    rows = sqlite.execute("SELECT #{columns.join(', ')} FROM #{table}")
    next if rows.empty?

    placeholders = columns.each_index.map { |i| "$#{i + 1}" }.join(', ')
    insert_sql = "INSERT INTO #{table} (#{columns.join(', ')}) VALUES (#{placeholders})"

    rows.each do |row|
      data = row_to_hash(row)
      params = columns.map { |column| data[column] }
      conn.exec_params(insert_sql, params)
    end
  end
end

SEQUENCE_TABLES.each { |table| set_sequence(pg, table) }

pg.close
sqlite.close

puts 'Migration complete.'
