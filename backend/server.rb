# frozen_string_literal: true

require 'sinatra'
require 'sinatra/json'
require 'sinatra/content_for'
require 'pg'
require 'json'
require 'prometheus/client'
require 'prometheus/client/formats/text'

# Configure Sinatra
set :port, 1010
set :bind, '0.0.0.0'
set :root, File.expand_path('..', __dir__)
set :public_folder, File.join(settings.root, 'frontend/public')
set :views, File.join(settings.root, 'frontend/templates')

REGISTRY = Prometheus::Client.registry
HTTP_REQUESTS_TOTAL = REGISTRY.counter(
  :http_requests_total,
  docstring: 'Total number of HTTP requests',
  labels: %i[method path status],
)
HTTP_REQUEST_DURATION_SECONDS = REGISTRY.histogram(
  :http_request_duration_seconds,
  docstring: 'HTTP request duration in seconds',
  labels: %i[method path],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
)

def metric_path(path)
  path.gsub(%r{/\d+}, '/:id')
end

before do
  request.env['metrics.request_started_at'] = Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

after do
  started_at = request.env['metrics.request_started_at']
  next unless started_at

  labels = {
    method: request.request_method,
    path: metric_path(request.path_info),
  }

  HTTP_REQUESTS_TOTAL.increment(labels: labels.merge(status: response.status.to_s))
  HTTP_REQUEST_DURATION_SECONDS.observe(
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at,
    labels: labels,
  )
end

# Database configuration
DB_HOST = ENV.fetch('DB_HOST', 'localhost')
DB_PORT = Integer(ENV.fetch('DB_PORT', '5432'))
DB_NAME = ENV.fetch('DB_NAME', 'recipe_cookbook')
DB_USER = ENV.fetch('DB_USER', 'recipe_user')
DB_PASSWORD = ENV.fetch('DB_PASSWORD', 'recipe_pass')
DB_SSLMODE = ENV.fetch('DB_SSLMODE', 'prefer')

# Helper method to get database connection
def db_connection
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

def db_exec(db, sql, params = [])
  db.exec_params(sql, params)
end

def db_first_row(db, sql, params = [])
  result = db.exec_params(sql, params)
  result.ntuples.positive? ? result[0] : nil
end

def db_first_value(db, sql, params = [])
  row = db_first_row(db, sql, params)
  row&.values&.first
end

# Helper method to convert rows to proper hashes
def row_to_hash(row)
  return nil if row.nil?

  row.reject { |k, _v| k.is_a?(Integer) }
end

def rows_to_hashes(rows)
  rows.map { |row| row_to_hash(row) }
end

get '/metrics' do
  content_type 'text/plain; version=0.0.4; charset=utf-8'
  Prometheus::Client::Formats::Text.marshal(REGISTRY)
end

# Initialize database (called on startup)
def init_db
  return unless ENV.fetch('DB_INIT', 'false').downcase == 'true'

  db = db_connection

  # Create tables
  db.exec(File.read(File.join(settings.root, 'backend/database/schema.pg.sql')))

  # Check if we need to seed
  recipe_count = db_first_value(db, 'SELECT COUNT(*) FROM recipes')

  if recipe_count.to_i.zero?
    puts 'Seeding database...'
    db.exec(File.read(File.join(settings.root, 'backend/database/seeds.sql')))
  end

  db.close
rescue StandardError => e
  puts "Database initialization error: #{e.message}"
end

# yo

# ============================================
# WEB ROUTES (HTML pages)
# ============================================

# Enhanced error logging for debugging
error do
  e = env['sinatra.error']
  puts "Sinatra error: \\#{e.class} - \\#{e.message}\\n\\#{e.backtrace.join('\\n')}" if e
  'Internal Server Error'
end

# Home page - display all recipes
get '/' do
  puts 'Route start: GET /'
  begin
    db = db_connection
    puts 'DB connected'

    recipes = db_exec(db, 'SELECT id, title, time_minutes, price, link FROM recipes')
    puts "Fetched recipes: \\#{recipes.ntuples} rows"
    recipes_with_tags = recipes.map do |recipe|
      tags = db_exec(
        db,
        'SELECT t.id, t.name FROM tags t
         JOIN recipe_tags rt ON t.id = rt.tag_id
         WHERE rt.recipe_id = $1',
        [recipe['id']],
      )

      {
        'id' => recipe['id'],
        'title' => recipe['title'],
        'time_minutes' => recipe['time_minutes'],
        'price' => recipe['price'],
        'link' => recipe['link'] || '',
        'tags' => rows_to_hashes(tags),
      }
    end

    db.close
    puts 'DB closed'
    erb :home, locals: { recipes: recipes_with_tags }
  rescue StandardError => e
    puts "Exception in GET /: \\#{e.class} - \\#{e.message}\\n\\#{e.backtrace.join('\\n')}"
    halt 500, 'Internal Server Error'
  end
end

# ============================================
# API DOCUMENTATION
# ============================================

# Serve OpenAPI schema
get '/api/schema' do
  content_type 'application/yaml'
  File.read(File.join(settings.root, 'backend/openapi/api-schema.yaml'))
end

# Swagger UI endpoint
get '/apidocs' do
  swagger_ui_html
end

def ingredients_for_recipe(db, id)
  db_exec(
    db,
    'SELECT i.id, i.name, ri.amount, ri.unit FROM ingredients i
     JOIN recipe_ingredients ri ON i.id = ri.ingredient_id
     WHERE ri.recipe_id = $1',
    [id],
  )
end

def tags_for_recipe(db, id)
  db_exec(
    db,
    'SELECT t.id, t.name FROM tags t
     JOIN recipe_tags rt ON t.id = rt.tag_id
     WHERE rt.recipe_id = $1',
    [id],
  )
end

def fetch_recipe_data(id)
  db = db_connection

  recipe = db_first_row(
    db,
    'SELECT id, title, time_minutes, price, link, description FROM recipes WHERE id = $1',
    [id],
  )

  return nil if recipe.nil?

  ingredients = ingredients_for_recipe(db, id)
  tags = tags_for_recipe(db, id)

  db.close

  {
    'id' => recipe['id'],
    'title' => recipe['title'],
    'time_minutes' => recipe['time_minutes'],
    'price' => recipe['price'],
    'link' => recipe['link'] || '',
    'description' => recipe['description'] || '',
    'ingredients' => rows_to_hashes(ingredients),
    'tags' => rows_to_hashes(tags),
  }
end

# Recipe detail page (web)
get '/recipes/:id/' do
  puts 'Route invoked: GET /recipes/:id/'
  recipe = fetch_recipe_data(params[:id])

  halt 404, 'Not Found' if recipe.nil?

  erb :recipe_detail, locals: { recipe: recipe }
end

def swagger_ui_html
  api_schema_url = "#{request.base_url}/api/schema"

  head = swagger_ui_head
  body = swagger_ui_body(api_schema_url)

  <<~HTML
    #{head}
    #{body}
  HTML
end

def swagger_ui_head
  <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Recipe Cookbook API - Swagger UI</title>
      <link rel="stylesheet" type="text/css" href="/swagger-ui/swagger-ui.css">
      <style>
        html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin: 0; padding: 0; }
      </style>
    </head>
  HTML
end

def swagger_ui_body(api_schema_url)
  <<~HTML
    <body>
      <div id="swagger-ui"></div>
      <script src="/swagger-ui/swagger-ui-bundle.js"></script>
      <script src="/swagger-ui/swagger-ui-standalone-preset.js"></script>
      <script>
        window.onload = function() {
          window.ui = SwaggerUIBundle({
            url: "#{api_schema_url}",
            dom_id: '#swagger-ui',
            deepLinking: true,
            presets: [
              SwaggerUIBundle.presets.apis,
              SwaggerUIStandalonePreset
            ],
            plugins: [
              SwaggerUIBundle.plugins.DownloadUrl
            ],
            layout: "StandaloneLayout"
          });
        };
      </script>
    </body>
    </html>
  HTML
end

# ============================================
# API ROUTES (JSON endpoints)
# ============================================

# API overview
get '/api' do
  puts 'Route invoked: GET /api'
  base_url = request.base_url

  json({
         create_user_url: "#{base_url}/api/user/create/",
         current_user_url: "#{base_url}/api/user/me/",
         user_token_url: "#{base_url}/api/user/token/",
         recipes_url: "#{base_url}/api/recipe/recipes/{?ingredients,tags}",
         recipe_url: "#{base_url}/api/recipe/recipes/{id}/",
         recipe_image_url: "#{base_url}/api/recipe/recipes/{id}/upload-image/",
         ingredients_url: "#{base_url}/api/recipe/ingredients/{?assigned_only}",
         ingredient_url: "#{base_url}/api/recipe/ingredients/{id}/",
         tags_url: "#{base_url}/api/recipe/tags/{?assigned_only}",
         tag_url: "#{base_url}/api/recipe/tags/{id}/",
       })
end

# ============================================
# USER API ENDPOINTS
# ============================================

# Create a new user
post '/api/user/create/' do
  puts 'Route invoked: POST /api/user/create/'
  data = JSON.parse(request.body.read)

  db = db_connection
  db_exec(
    db,
    'INSERT INTO users (email, password, name) VALUES ($1, $2, $3) RETURNING id',
    [data['email'], data['password'], data['name']],
  )
  db.close

  status 201
  json({
         email: data['email'],
         name: data['name'],
       })
end

# Get current user
get '/api/user/me/' do
  puts 'Route invoked: GET /api/user/me/'
  json({
         email: 'user@example.com',
         name: 'Example User',
       })
end

# Update current user (full update)
put '/api/user/me/' do
  puts 'Route invoked: PUT /api/user/me/'
  data = JSON.parse(request.body.read)

  json({
         email: data['email'],
         name: data['name'],
       })
end

# Partial update current user
patch '/api/user/me/' do
  puts 'Route invoked: PATCH /api/user/me/'
  data = JSON.parse(request.body.read)

  response = {
    email: data['email'] || 'user@example.com',
    name: data['name'] || 'Example User',
  }

  json(response)
end

# Create user token (login)
post '/api/user/token/' do
  puts 'Route invoked: POST /api/user/token/'
  data = JSON.parse(request.body.read)

  json({
         email: data['email'],
         password: data['password'],
       })
end

# ============================================
# RECIPE API ENDPOINTS
# ============================================

# List all recipes
get '/api/recipe/recipes/' do
  puts 'Route invoked: GET /api/recipe/recipes/'

  db = db_connection
  recipes = db_exec(db, 'SELECT id, title, time_minutes, price, link FROM recipes')

  result = recipes.map do |recipe|
    ingredients = db_exec(
      'SELECT i.id, i.name, ri.amount, ri.unit FROM ingredients i
       JOIN recipe_ingredients ri ON i.id = ri.ingredient_id
       WHERE ri.recipe_id = $1',
      [recipe['id']],
    )

    tags = db_exec(
      'SELECT t.id, t.name FROM tags t
       JOIN recipe_tags rt ON t.id = rt.tag_id
       WHERE rt.recipe_id = $1',
      [recipe['id']],
    )

    {
      'id' => recipe['id'],
      'title' => recipe['title'],
      'time_minutes' => recipe['time_minutes'],
      'price' => recipe['price'],
      'link' => recipe['link'] || '',
      'ingredients' => rows_to_hashes(ingredients),
      'tags' => rows_to_hashes(tags),
    }
  end

  db.close
  json(result)
end

# Create a new recipe
post '/api/recipe/recipes/' do
  puts 'Route invoked: POST /api/recipe/recipes/'
  data = JSON.parse(request.body.read)

  status 201
  json({
         id: 1,
         title: data['title'],
         time_minutes: data['time_minutes'],
         price: data['price'],
         link: data['link'] || '',
         tags: data['tags'] || [],
         ingredients: data['ingredients'] || [],
         description: data['description'] || '',
       })
end

# Get a specific recipe
get '/api/recipe/recipes/:id/' do
  puts 'Route invoked: GET /api/recipe/recipes/:id/'
  id = params[:id]

  json(fetch_recipe_data(id))
end

# Update a recipe (full update)
put '/api/recipe/recipes/:id/' do
  puts 'Route invoked: PUT /api/recipe/recipes/:id/'
  id = params[:id]
  data = JSON.parse(request.body.read)

  json({
         id: id.to_i,
         title: data['title'],
         time_minutes: data['time_minutes'],
         price: data['price'],
         link: data['link'] || '',
         tags: data['tags'] || [],
         ingredients: data['ingredients'] || [],
         description: data['description'] || '',
       })
end

# Partial update a recipe
patch '/api/recipe/recipes/:id/' do
  puts 'Route invoked: PATCH /api/recipe/recipes/:id/'
  id = params[:id]
  data = JSON.parse(request.body.read)

  response = {
    id: id.to_i,
    title: data['title'] || 'Sample Recipe',
    time_minutes: data['time_minutes'] || 30,
    price: data['price'] || '10.00',
    link: data['link'] || '',
    tags: data['tags'] || [],
    ingredients: data['ingredients'] || [],
    description: data['description'] || '',
  }

  json(response)
end

# Delete a recipe
delete '/api/recipe/recipes/:id/' do
  puts 'Route invoked: DELETE /api/recipe/recipes/:id/'
  id = params[:id]

  db = db_connection

  # Delete the recipe (CASCADE will handle recipe_ingredients and recipe_tags)
  db_exec(db, 'DELETE FROM recipes WHERE id = $1', [id])
  db.close

  status 204
end

# Upload recipe image
post '/api/recipe/recipes/:id/upload-image/' do
  puts 'Route invoked: POST /api/recipe/recipes/:id/upload-image/'
  id = params[:id]

  json({
         id: id.to_i,
         image: 'http://example.com/image.jpg',
       })
end

# ============================================
# INGREDIENT API ENDPOINTS
# ============================================

# List all ingredients
get '/api/recipe/ingredients/' do
  puts 'Route invoked: GET /api/recipe/ingredients/'

  db = db_connection
  ingredients = db_exec(db, 'SELECT id, name FROM ingredients')
  db.close

  result = rows_to_hashes(ingredients)
  json(result)
end

# Update an ingredient (full update)
put '/api/recipe/ingredients/:id/' do
  puts 'Route invoked: PUT /api/recipe/ingredients/:id/'
  id = params[:id]
  data = JSON.parse(request.body.read)

  json({
         id: id.to_i,
         name: data['name'],
       })
end

# Partial update an ingredient
patch '/api/recipe/ingredients/:id/' do
  puts 'Route invoked: PATCH /api/recipe/ingredients/:id/'
  id = params[:id]
  data = JSON.parse(request.body.read)

  json({
         id: id.to_i,
         name: data['name'] || 'Sample Ingredient',
       })
end

# Delete an ingredient
delete '/api/recipe/ingredients/:id/' do
  puts 'Route invoked: DELETE /api/recipe/ingredients/:id/'
  id = params[:id]

  db = db_connection
  db_exec(db, 'DELETE FROM ingredients WHERE id = $1', [id])
  db.close

  status 204
end

# ============================================
# TAG API ENDPOINTS
# ============================================

# List all tags
get '/api/recipe/tags/' do
  puts 'Route invoked: GET /api/recipe/tags/'

  db = db_connection
  tags = db_exec(db, 'SELECT id, name FROM tags')
  db.close

  result = rows_to_hashes(tags)
  json(result)
end

# Update a tag (full update)
put '/api/recipe/tags/:id/' do
  puts 'Route invoked: PUT /api/recipe/tags/:id/'
  id = params[:id]
  data = JSON.parse(request.body.read)

  json({
         id: id.to_i,
         name: data['name'],
       })
end

# Partial update a tag
patch '/api/recipe/tags/:id/' do
  puts 'Route invoked: PATCH /api/recipe/tags/:id/'
  id = params[:id]
  data = JSON.parse(request.body.read)

  json({
         id: id.to_i,
         name: data['name'] || 'Sample Tag',
       })
end

# Delete a tag
delete '/api/recipe/tags/:id/' do
  puts 'Route invoked: DELETE /api/recipe/tags/:id/'
  id = params[:id]

  db = db_connection
  db_exec(db, 'DELETE FROM tags WHERE id = $1', [id])
  db.close

  status 204
end

# ============================================
# Application startup
# ============================================

# Log details for 404s to help debug missing routes
not_found do
  puts "NotFound handler triggered for path: #{request.path_info}"
  puts "Request env keys: #{request.env.keys.grep(/REQUEST|PATH|HTTP/).join(', ')}"
  content_type 'text/html'
  '<h1>Not Found</h1>'
end

# Initialize database before starting server
configure do
  init_db
end
