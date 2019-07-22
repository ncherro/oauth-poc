require 'sinatra'
require 'sinatra/json'
require 'sinatra/flash'

require 'logger'
require 'net/http'
require 'date'
require 'uri'

HOST = ENV.fetch('HOST', 'localhost')
PORT = ENV.fetch('PORT', 8080)
NONCE_DELIMITER = '-_-'.freeze

API_BASE = 'namely.com/api/v1'.freeze

OAUTH_CLIENT_ID = ENV.fetch('OAUTH_CLIENT_ID')
OAUTH_CLIENT_SECRET = ENV.fetch('OAUTH_CLIENT_SECRET')

p "Starting Sinatra on port #{PORT}"

set :port, PORT
set :bind, '0.0.0.0'
enable :sessions
set :logger, Logger.new(STDOUT)

register Sinatra::Flash

# routes to trigger the flow
# we're clearing the session to explicitly 'log out'
get '/' do
  clear_session

  subdomain = params[:subdomain]
  kick_off_oauth(subdomain) if subdomain

  erb :index
end

post '/' do
  kick_off_oauth(params[:subdomain])
end

# our OAuth handler - completes the handshake and redirects to /me on success
get '/api/clients/redirect_success' do
  logger.info(params)

  # the `state` value tells us which subdomain the user authenticated against
  # we store it in a session, along with tokens, below
  nonce = params[:state]
  halt(400, 'the "state" parameter is required') unless nonce

  # ensure the state returned matches the nonce we set earlier
  halt(400, 'invalid "state" was supplied') unless nonce == session[:nonce]

  # grab the subdomain
  subdomain = nonce.split(NONCE_DELIMITER)[0]

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
    logger.info('Successful OAuth exchange')
    logger.info(resp_body)
    set_session(resp_body, subdomain)

    redirect '/api/profiles/me'
  else
    # something went wrong - show the response
    status(resp.code)
    json(resp_body)
  end
end

# wildcard access to the namely API - requires authorization
get '/api/*' do
  api_request('/' + params['splat'].join('/'))
end

# helpers
helpers do
  # 1. generate a nonce and store it in our session
  # 2.  redirect the user to Namely's oauth2/authorize endpoint to kick off the
  # OAuth handshake
  def kick_off_oauth(subdomain)
    nonce = "#{subdomain}#{NONCE_DELIMITER}#{DateTime.now.strftime('%Q')}"
    session[:nonce] = nonce

    url = "https://#{subdomain}.#{API_BASE}/oauth2/authorize?" \
      'response_type=code&' \
      "client_id=#{OAUTH_CLIENT_ID}&" \
      "redirect_uri=http://#{HOST}:#{PORT}/api/clients/redirect_success&" \
      "state=#{nonce}"

    logger.info("Redirecting to #{url}")

    redirect url
  end

  # confirm that we have a subdomain and access_token in our session
  def auth_check
    return if session[:subdomain] && session[:access_token]

    flash[:error] = 'Unauthenticated'
    redirect('/')
  end

  def set_session(resp_body, subdomain = nil)
    logger.info('Old session')
    logger.info(session)

    expires_at = Time.now + resp_body['expires_in'].to_i
    logger.info("Setting session - new token expires at #{expires_at}")

    session[:access_token] = resp_body['access_token']
    session[:access_token_expires_at] = expires_at
    session[:refresh_token] = resp_body['refresh_token']
    session[:subdomain] = subdomain if subdomain

    logger.info('New session')
    logger.info(session)
  end

  def clear_session
    session[:access_token] = session[:access_token_expires_at] =
      session[:refresh_token] = session[:subdomain] = session[:nonce] = nil
  end

  # refresh our token
  def refresh_token
    logger.info('Refreshing...')

    subdomain = session[:subdomain]
    old_refresh_token = session[:refresh_token]

    # perform the exchange
    uri = URI.parse("https://#{subdomain}.#{API_BASE}/oauth2/token")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req.body = 'grant_type=refresh_token&' \
      "client_id=#{OAUTH_CLIENT_ID}&" \
      "client_secret=#{OAUTH_CLIENT_SECRET}&" \
      "redirect_uri=http://#{HOST}:#{PORT}/api/clients/redirect_success&" \
      "refresh_token=#{old_refresh_token}"

    resp = http.request(req)
    resp_body = JSON.parse(resp.body)

    if resp.code == '200'
      # store subdomain and tokens in the session for later use
      set_session(resp_body)
      return true
    end
    return false
  end

  # wraps GET requests to the API
  def api_request(orig_uri, attempt_refresh = true)
    auth_check

    expires_at = session[:access_token_expires_at]

    if Time.now > expires_at
      logger.info('Token is expired')
      unless refresh_token
        redirect('/')
      end
			expires_at = session[:access_token_expires_at]
    end

    logger.info("Token is fresh - expires in #{expires_at - Time.now} seconds")

    uri = URI("https://#{session[:subdomain]}.#{API_BASE}/#{orig_uri}")
    headers = {
      'Authorization' => "Bearer #{session[:access_token]}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    resp = http.get(uri.path, headers)
    resp_body = JSON.parse(resp.body)

    # TODO: only refresh on specific response codes
    if resp.code == '403' && attempt_refresh
      logger.warn("Bad API response code - #{resp.code} - attempting refresh")
      # 1. refresh the token
      refreshed = refresh_token
      # 2. re-run the API request, without attempting refresh
      return api_request(orig_uri, false) if refreshed
    end

    # return the response
    status(resp.code)
    json(resp_body)
  end
end

