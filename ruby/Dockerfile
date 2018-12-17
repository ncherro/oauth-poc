FROM ruby:2.5-slim

RUN apt-get update && apt-get upgrade -y

ENV APP_HOME /app
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME
COPY ./Gemfile* .

RUN bundle install

ENTRYPOINT ["ruby", "/app/app.rb"]
