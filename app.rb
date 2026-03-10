# frozen_string_literal: true

require 'sinatra'
require 'sinatra/json'
require 'sinatra/content_for'
require 'sqlite3'
require 'json'

# Configure Sinatra
set :port, 3000
set :bind, '0.0.0.0'
set :public_folder, 'static'

# Database configuration
DATABASE = 'app.db'

# Helper method to get database connection
def db_connection
  db = SQLite3::Database.new(DATABASE)
  db.results_as_hash = true
  db.execute('PRAGMA foreign_keys = ON')
  db
end

# Helper method to convert SQLite rows to proper hashes
def row_to_hash(row)
  return nil if row.nil?

  row.reject { |k, _v| k.is_a?(Integer) }
end

def rows_to_hashes(rows)
  rows.map { |row| row_to_hash(row) }
end

# Initialize database (called on startup)
def init_db
  db = db_connection

  # Create tables
  db.execute_batch(File.read('db/schema.sql'))

  # Check if we need to seed
  recipe_count = db.get_first_value('SELECT COUNT(*) FROM recipes')

  if recipe_count.to_i.zero?
    puts 'Seeding database...'
    db.execute_batch(File.read('db/seeds.sql'))
  end

  db.close
rescue StandardError => e
  puts "Database initialization error: #{e.message}"
end

# ============================================
# WEB ROUTES (HTML pages)
# ============================================

# Home page - display all recipes
get '/' do
  puts 'Route invoked: GET /'
  db = db_connection

  recipes = db.execute('SELECT id, title, time_minutes, price, link FROM recipes')

  recipes_with_tags = recipes.map do |recipe|
    tags = db.execute(
      'SELECT t.id, t.name FROM tags t
       JOIN recipe_tags rt ON t.id = rt.tag_id
       WHERE rt.recipe_id = ?',
      recipe['id']
    )

    {
      'id' => recipe['id'],
      'title' => recipe['title'],
      'time_minutes' => recipe['time_minutes'],
      'price' => recipe['price'],
      'link' => recipe['link'] || '',
      'tags' => rows_to_hashes(tags)
    }
  end

  db.close
  erb :home, locals: { recipes: recipes_with_tags }
end

# Recipe detail page
get '/recipes/:id/' do
  puts 'Route invoked: GET /recipes/:id/'
  db = db_connection
  id = params[:id]

  recipe = db.get_first_row(
    'SELECT id, title, time_minutes, price, link, description FROM recipes WHERE id = ?',
    id
  )

  ingredients = db.execute(
    'SELECT i.id, i.name, ri.amount, ri.unit FROM ingredients i
     JOIN recipe_ingredients ri ON i.id = ri.ingredient_id
     WHERE ri.recipe_id = ?',
    id
  )

  tags = db.execute(
    'SELECT t.id, t.name FROM tags t
     JOIN recipe_tags rt ON t.id = rt.tag_id
     WHERE rt.recipe_id = ?',
    id
  )

  db.close

  recipe_data = {
    'id' => recipe['id'],
    'title' => recipe['title'],
    'time_minutes' => recipe['time_minutes'],
    'price' => recipe['price'],
    'link' => recipe['link'] || '',
    'description' => recipe['description'] || '',
    'ingredients' => rows_to_hashes(ingredients),
    'tags' => rows_to_hashes(tags)
  }

  erb :recipe_detail, locals: { recipe: recipe_data }
end

# ============================================
# API DOCUMENTATION
# ============================================

# Serve OpenAPI schema
get '/api/schema' do
  content_type 'application/yaml'
  File.read('api-schema.yaml')
end

# Swagger UI endpoint
get '/apidocs' do
  html = <<~HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Recipe Cookbook API - Swagger UI</title>
      <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css">
      <style>
        html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin: 0; padding: 0; }
      </style>
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js"></script>
      <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-standalone-preset.js"></script>
      <script>
        window.onload = function() {
          window.ui = SwaggerUIBundle({
            url: "/api/schema",
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
  html
end

# ============================================
# API ROUTES (JSON endpoints)
# ============================================

# API overview
get '/api' do
  puts 'Route invoked: GET /api'
  json({
         create_user_url: 'http://localhost:3000/api/user/create/',
         current_user_url: 'http://localhost:3000/api/user/me/',
         user_token_url: 'http://localhost:3000/api/user/token/',
         recipes_url: 'http://localhost:3000/api/recipe/recipes/{?ingredients,tags}',
         recipe_url: 'http://localhost:3000/api/recipe/recipes/{id}/',
         recipe_image_url: 'http://localhost:3000/api/recipe/recipes/{id}/upload-image/',
         ingredients_url: 'http://localhost:3000/api/recipe/ingredients/{?assigned_only}',
         ingredient_url: 'http://localhost:3000/api/recipe/ingredients/{id}/',
         tags_url: 'http://localhost:3000/api/recipe/tags/{?assigned_only}',
         tag_url: 'http://localhost:3000/api/recipe/tags/{id}/'
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
  db.execute(
    'INSERT INTO users (email, password, name) VALUES (?, ?, ?)',
    data['email'], data['password'], data['name']
  )
  db.last_insert_row_id
  db.close

  status 201
  json({
         email: data['email'],
         name: data['name']
       })
end

# Get current user
get '/api/user/me/' do
  puts 'Route invoked: GET /api/user/me/'
  json({
         email: 'user@example.com',
         name: 'Example User'
       })
end

# Update current user (full update)
put '/api/user/me/' do
  puts 'Route invoked: PUT /api/user/me/'
  data = JSON.parse(request.body.read)

  json({
         email: data['email'],
         name: data['name']
       })
end

# Partial update current user
patch '/api/user/me/' do
  puts 'Route invoked: PATCH /api/user/me/'
  data = JSON.parse(request.body.read)

  response = {
    email: data['email'] || 'user@example.com',
    name: data['name'] || 'Example User'
  }

  json(response)
end

# Create user token (login)
post '/api/user/token/' do
  puts 'Route invoked: POST /api/user/token/'
  data = JSON.parse(request.body.read)

  json({
         email: data['email'],
         password: data['password']
       })
end

# ============================================
# RECIPE API ENDPOINTS
# ============================================

# List all recipes
get '/api/recipe/recipes/' do
  puts 'Route invoked: GET /api/recipe/recipes/'

  db = db_connection
  recipes = db.execute('SELECT id, title, time_minutes, price, link FROM recipes')

  result = recipes.map do |recipe|
    ingredients = db.execute(
      'SELECT i.id, i.name, ri.amount, ri.unit FROM ingredients i
       JOIN recipe_ingredients ri ON i.id = ri.ingredient_id
       WHERE ri.recipe_id = ?',
      recipe['id']
    )

    tags = db.execute(
      'SELECT t.id, t.name FROM tags t
       JOIN recipe_tags rt ON t.id = rt.tag_id
       WHERE rt.recipe_id = ?',
      recipe['id']
    )

    {
      'id' => recipe['id'],
      'title' => recipe['title'],
      'time_minutes' => recipe['time_minutes'],
      'price' => recipe['price'],
      'link' => recipe['link'] || '',
      'ingredients' => rows_to_hashes(ingredients),
      'tags' => rows_to_hashes(tags)
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
         description: data['description'] || ''
       })
end

# Get a specific recipe
get '/api/recipe/recipes/:id/' do
  puts 'Route invoked: GET /api/recipe/recipes/:id/'
  id = params[:id]

  db = db_connection

  recipe = db.get_first_row(
    'SELECT id, title, time_minutes, price, link, description FROM recipes WHERE id = ?',
    id
  )

  ingredients = db.execute(
    'SELECT i.id, i.name, ri.amount, ri.unit FROM ingredients i
     JOIN recipe_ingredients ri ON i.id = ri.ingredient_id
     WHERE ri.recipe_id = ?',
    id
  )

  tags = db.execute(
    'SELECT t.id, t.name FROM tags t
     JOIN recipe_tags rt ON t.id = rt.tag_id
     WHERE rt.recipe_id = ?',
    id
  )

  db.close

  json({
         id: recipe['id'],
         title: recipe['title'],
         time_minutes: recipe['time_minutes'],
         price: recipe['price'],
         link: recipe['link'] || '',
         description: recipe['description'] || '',
         ingredients: rows_to_hashes(ingredients),
         tags: rows_to_hashes(tags)
       })
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
         description: data['description'] || ''
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
    description: data['description'] || ''
  }

  json(response)
end

# Delete a recipe
delete '/api/recipe/recipes/:id/' do
  puts 'Route invoked: DELETE /api/recipe/recipes/:id/'
  id = params[:id]

  db = db_connection

  # Enable foreign keys to ensure CASCADE delete works
  db.execute('PRAGMA foreign_keys = ON')

  # Delete the recipe (CASCADE will handle recipe_ingredients and recipe_tags)
  db.execute('DELETE FROM recipes WHERE id = ?', id)
  db.close

  status 204
end

# Upload recipe image
post '/api/recipe/recipes/:id/upload-image/' do
  puts 'Route invoked: POST /api/recipe/recipes/:id/upload-image/'
  id = params[:id]

  json({
         id: id.to_i,
         image: 'http://example.com/image.jpg'
       })
end

# ============================================
# INGREDIENT API ENDPOINTS
# ============================================

# List all ingredients
get '/api/recipe/ingredients/' do
  puts 'Route invoked: GET /api/recipe/ingredients/'

  db = db_connection
  ingredients = db.execute('SELECT id, name FROM ingredients')
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
         name: data['name']
       })
end

# Partial update an ingredient
patch '/api/recipe/ingredients/:id/' do
  puts 'Route invoked: PATCH /api/recipe/ingredients/:id/'
  id = params[:id]
  data = JSON.parse(request.body.read)

  json({
         id: id.to_i,
         name: data['name'] || 'Sample Ingredient'
       })
end

# Delete an ingredient
delete '/api/recipe/ingredients/:id/' do
  puts 'Route invoked: DELETE /api/recipe/ingredients/:id/'
  id = params[:id]

  db = db_connection
  db.execute('DELETE FROM ingredients WHERE id = ?', id)
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
  tags = db.execute('SELECT id, name FROM tags')
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
         name: data['name']
       })
end

# Partial update a tag
patch '/api/recipe/tags/:id/' do
  puts 'Route invoked: PATCH /api/recipe/tags/:id/'
  id = params[:id]
  data = JSON.parse(request.body.read)

  json({
         id: id.to_i,
         name: data['name'] || 'Sample Tag'
       })
end

# Delete a tag
delete '/api/recipe/tags/:id/' do
  puts 'Route invoked: DELETE /api/recipe/tags/:id/'
  id = params[:id]

  db = db_connection
  db.execute('DELETE FROM tags WHERE id = ?', id)
  db.close

  status 204
end

# ============================================
# Application startup
# ============================================

# Initialize database before starting server
configure do
  init_db
end
