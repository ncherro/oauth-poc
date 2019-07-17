# Namely OAuth POC - Ruby

Authenticating with Namely via OAuth

## Requirements

- docker
- docker-compose

## Setup

1. follow [Namely's development
   docs](https://developers.namely.com/1.0/authentication/authentication) to
   create an OAuth client on your Namely subdomain - set 'Redirect URIs' to
   `http://localhost:8080/api/clients/redirect_success` (assuming your Docker
   host is accessible at localhost)
1. `cp .env.example .env` and set the `OAUTH_CLIENT_ID` and
   `OAUTH_SECRET_VALUES` to the values returned by the form
1. run `docker-compose build app` to build
1. run `docker-compose up app` to spin the web server up on port 8080 of your
   docker host

Now visit http://localhost:8080. Entering a subodomain and submitting the form
will redirect you to this URL to kick off the OAuth handshake:

`https://<SUBDOMAIN>.namely.com/api/v1/oauth2/authorize?response_type=code&client_id=<OAUTH_CLIENT_ID>&redirect_uri=<REDIRECT_URI>&state=<SUBDOMAIN|TIMESTAMP>`

That's it! Once logged in, you will be redirected to http://localhost:8080/me,
which displays your user's information for the Namely subdomain you entered.
Visit http://localhost:8080/company to get company information.

## To do

- ~~Guard /me and /company with auth checks~~
- ~~Flash messages~~
- ~~Refresh tokens~~
- ~~Pass a proper nonce in state~~
- Tests!
