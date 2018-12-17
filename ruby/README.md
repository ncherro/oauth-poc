# Namely OAuth POC - Ruby

Authenticating with Namely via OAuth

## Requirements

- docker
- docker-compose

## Setup

1. follow [Namely's development
   docs](https://developers.namely.com/1.0/authentication/authentication) to
   create an OAuth client on your Namely subdomain - set 'Redirect URIs' to
   `http://dockerhost:8080/api/clients/redirect_success` (assuming you've
   aliased `dockerhost` to your docker machine's IP address locally)
1. `cp .env.example .env` and set the `OAUTH_CLIENT_ID` and
   `OAUTH_SECRET_VALUES` to the values returned by the form
1. run `docker-compose build app` to build
1. run `docker-compose up app` to spin the web server up on port 8080 of your
   docker host

Now visit http://dockerhost:8080. Entering a subodomain in the form will
effectively redirect you to this URL to kick off the OAuth handshake:

`https://<SUBDOMAIN>.namely.com/api/v1/oauth2/authorize?response_type=code&client_id=<OAUTH_CLIENT_ID>&redirect_uri=<REDIRECT_URI>&state=<SUBDOMAIN>`

That's it! Once logged in, you will be redirected to http://dockerhost:8080/me,
which displays your user's information for the Namely subdomain you entered.
Visit http://dockerhost:8080/company to get company information.

## To do

- Refresh tokens
- Guard /me and /company with auth checks
- Write tests
