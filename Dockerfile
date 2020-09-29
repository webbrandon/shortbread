FROM rails:4.1.4

ARG PORT=8080
ARG RACK_ENV=development

EXPOSE ${PORT}

RUN mkdir /opt/app
COPY . /opt/app

WORKDIR /opt/app

RUN bundle install
RUN chmod +x entrypoint.sh

ENTRYPOINT ./entrypoint.sh
# We could also take advantage of "procfile" with proper tooling.
CMD bundle exec rails server thin -p ${PORT} -e ${RACK_ENV}
