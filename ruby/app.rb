require 'sinatra'
require 'sinatra/json'
require 'logger'

require 'net/http'
require 'uri'

PORT = ENV.fetch('PORT', 8080)
API_BASE = 'namely.com/api/v1'.freeze
OAUTH_CLIENT_ID = ENV.fetch('OAUTH_CLIENT_ID')
OAUTH_CLIENT_SECRET = ENV.fetch('OAUTH_CLIENT_SECRET')

p "Starting Sinatra on port #{PORT}"
set :port, PORT
set :bind, '0.0.0.0'
enable :sessions
set :logger, Logger.new(STDOUT)

get '/api/clients/redirect_success' do
  logger.info(params)

  # the `state` value tells us which subdomain the user authenticated against
  # we store it in a session, along with tokens, below
  subdomain = params[:state]
  halt(400, 'the "state" parameter is required') unless subdomain

  # we'll exchange the `code` value for access / refresh tokens below
  code = params[:code]
  halt(400, 'the "code" parameter is required') unless code

  # perform the exchange
  uri = URI.parse("https://#{subdomain}.#{API_BASE}/oauth2/token")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  req = Net::HTTP::Post.new(uri.request_uri)
  req.body = 'grant_type=authorization_code&' \
    "client_id=#{OAUTH_CLIENT_ID}&" \
    "client_secret=#{OAUTH_CLIENT_SECRET}&" \
    "code=#{code}"

  resp = http.request(req)
  resp_body = JSON.parse(resp.body)

  if resp.code == '200'
    # store subdomain and tokens in the session for later use
    session[:subdomain] = subdomain
    session[:access_token] = resp_body['access_token']
    session[:refresh_token] = resp_body['refresh_token']
    redirect '/me'
  else
    json(resp_body)
  end
end

get '/me' do
  logger.info(session)

  # pull info from the subdomain to which the user authenticated using their
  # access token
  uri = URI("https://#{session[:subdomain]}.#{API_BASE}/profiles/me")
  headers = {
    'Authorization' => "Bearer #{session[:access_token]}",
    'Content-Type' => 'application/json',
    'Accept' => 'application/json'
  }
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  resp = http.get(uri.path, headers)
  resp_body = JSON.parse(resp.body)

  json(resp_body)
end

get '/company' do
  logger.info(session)

  # pull info from the subdomain to which the user authenticated using their
  # access token
  uri = URI("https://#{session[:subdomain]}.#{API_BASE}/companies/info")
  headers = {
    'Authorization' => "Bearer #{session[:access_token]}",
    'Content-Type' => 'application/json',
    'Accept' => 'application/json'
  }
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  resp = http.get(uri.path, headers)
  resp_body = JSON.parse(resp.body)

  json(resp_body)
end
