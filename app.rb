require 'bundler/setup'

require 'sinatra'
require 'oauth2'
require 'json'
require 'dotenv'
require 'rest-client'

Dotenv.load

enable :sessions

def client
  OAuth2::Client.new(
    ENV['OAUTH2_CLIENT_ID'],
    ENV['OAUTH2_CLIENT_SECRET'],
    site: ENV['OAUTH2_API_BASE_URL']
  )
end

get '/' do
  unless session[:access_token].nil?
    @profile = json_response_for_path('/api/user/profile')
  end

  erb :root
end

get '/auth' do
  redirect client.auth_code.authorize_url(
    :redirect_uri => redirect_uri,
    :scope => 'all'
  )
end

get '/logout' do
  session[:access_token] = nil
  redirect '/'
end
get '/auth/callback' do
  access_token = client.auth_code.get_token(params[:code], redirect_uri: redirect_uri)
  session[:access_token] = access_token.token
  redirect '/'
end

post '/import' do
  redirect '/' if session[:access_token].nil? or params[:ris_file].nil?

  import = RestClient.post "#{ENV['OAUTH2_API_BASE_URL']}/api/user/references/import",
             { 'source' => params[:ris_file][:tempfile], multipart: true },
             {:Authorization => "Bearer #{session[:access_token]}", :Accept => 'application/vnd.refme-v1+json'}
  puts "Imported!"
  @import_response = JSON.parse(import)
  erb :import_response
end

def json_response_for_path(url)
  access_token = OAuth2::AccessToken.new(client, session[:access_token])
  p access_token
  JSON.parse(access_token.get(url, { headers: {'Accept': 'application/vnd.refme-v1+json'} }).body)
rescue OAuth2::Error => e
  puts e
  session[:access_token] = nil
  redirect '/'
end

def redirect_uri
  uri = URI.parse(request.url)
  uri.path = '/auth/callback'
  uri.query = nil
  uri.to_s
end