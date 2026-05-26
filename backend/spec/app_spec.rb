# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Recipe Cookbook app' do
  it 'normalizes numeric URL segments for metrics labels' do
    expect(metric_path('/api/recipe/recipes/42/')).to eq('/api/recipe/recipes/:id/')
  end

  it 'returns a healthy API overview payload' do
    get '/api'

    expect(last_response).to be_ok
    payload = JSON.parse(last_response.body)
    expect(payload).to include('recipes_url', 'tags_url', 'ingredients_url')
  end

  it 'returns ingredient list as JSON array' do
    get '/api/recipe/ingredients/'

    expect(last_response).to be_ok
    payload = JSON.parse(last_response.body)
    expect(payload).to be_an(Array)
    expect(payload).not_to be_empty
    expect(payload.first).to include('id', 'name')
  end

  it 'creates a user through the API' do
    post '/api/user/create/', { email: 'test@example.com', password: 'secret', name: 'Test User' }.to_json,
         { 'CONTENT_TYPE' => 'application/json' }

    expect(last_response.status).to eq(201)
    payload = JSON.parse(last_response.body)
    expect(payload).to include('email' => 'test@example.com', 'name' => 'Test User')
  end

  it 'returns metrics in Prometheus text format' do
    get '/metrics'

    expect(last_response).to be_ok
    expect(last_response.headers['Content-Type']).to include('text/plain')
    expect(last_response.body).to include('http_requests_total')
  end
end
