FROM ruby:3.2.1

WORKDIR /usr/src/app
RUN gem install bundler

COPY Gemfile ./
COPY Gemfile.lock ./
RUN bundle install

COPY ./ ./
RUN bundle install

EXPOSE 4223
ENTRYPOINT './entrypoint.sh'
