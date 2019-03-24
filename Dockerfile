FROM pozylon/meteor-docker-auto as meteor

# https://github.com/coreos/bugs/issues/1095#issuecomment-336872867
RUN apt-get install -y bsdtar && ln -sf $(which bsdtar) $(which tar)

RUN mkdir /home/meteor
RUN usermod -d /home/meteor meteor
RUN chown -R meteor:meteor /home/meteor

ADD . /source
WORKDIR /source
RUN chown -R meteor /source

USER meteor

WORKDIR /source

RUN meteor npm install
RUN meteor npm run lint
RUN meteor npm run testunit

RUN meteor build --server-only --directory /tmp/build-test

RUN ls /tmp/build-test

RUN mkdir /tmp/build/ &&\
  cd /tmp/build-test &&\
  tar czf /tmp/build/Rocket.Chat.tar.gz bundle &&\
  cd /tmp/build-test/bundle/programs/server &&\
  npm install
RUN cd /tmp/build &&\
  tar xzf Rocket.Chat.tar.gz &&\
  rm Rocket.Chat.tar.gz


FROM rocketchat/base:8

COPY --from=meteor /tmp/build /app

MAINTAINER buildmaster@rocket.chat

RUN set -x \
  && cd /app/bundle/programs/server \
  && npm install \
  && npm cache clear --force \
  && chown -R rocketchat:rocketchat /app

USER rocketchat

VOLUME /app/uploads

WORKDIR /app/bundle

# needs a mongoinstance - defaults to container linking with alias 'mongo'
ENV DEPLOY_METHOD=docker \
  NODE_ENV=production \
  MONGO_URL=mongodb://mongo:27017/rocketchat \
  HOME=/tmp \
  PORT=3000 \
  ROOT_URL=http://localhost:3000 \
  Accounts_AvatarStorePath=/app/uploads

EXPOSE 3000

CMD ["node", "main.js"]
