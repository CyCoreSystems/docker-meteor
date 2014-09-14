#!/bin/bash
# Set default settings, pull repository, build
# app, etc., _if_ we are not given a different
# command.  If so, execute that command instead.
set -e

# Default values
: ${APP_DIR:="/var/www"}
: ${BRANCH:="master"}
: ${MONGO_URL:="mongodb://${MONGO_PORT_27017_TCP_ADDR}:${MONGO_PORT_27017_TCP_PORT}/${DB}"}
: ${PORT:="80"}


# If we were given arguments, run them instead
if [ $? -gt 1 ]; then
   exec "$@"
fi

# If we are provided a GITHUB_DEPLOY_KEY (path), then
# copy it into /root/.ssh and setup a github rule to use it
if [ -n "${GITHUB_DEPLOY_KEY}" ]; then
   if [ ! -f /root/.ssh/${GITHUB_DEPLOY_KEY} ]; then
      mkdir -p /root/.ssh
      cp ${GITHUB_DEPLOY_KEY} /root/.ssh/
      cat << ENDHERE >> /root/.ssh/config
Host github.com
  Identity /root/.ssh/${GITHUB_DEPLOY_KEY}
ENDHERE
   fi
fi

mkdir -p /usr/src

if [ -n "${REPO}" ]; then
   echo "Getting ${REPO}..."
   if [ -e /usr/src/app/.git ]; then
      pushd /usr/src/app
      git fetch
      popd
   else
      git clone ${REPO} /usr/src/app
   fi

   cd /usr/src/app

   echo "Switching to branch/tag ${BRANCH}..."
   git checkout ${BRANCH}

   # Bundle the Meteor app
   mkdir -p /var/www/bundle
   meteor bundle --directory /var/www/bundle

fi

if [ -n "${BUNDLE_URL}" ]; then
   echo "Getting Meteor bundle..."
   wget -O /tmp/bundle.tgz ${BUNDLE_URL}
   tar xf /tmp/bundle.tgz -C ${APP_DIR}
fi

# See if the actual bundle is in the bundle
# subdirectory (default)
if [ -d ${APP_DIR}/bundle ]; then
   APP_DIR=${APP_DIR}/bundle
fi

# Install NPM modules
if [ -e ${APP_DIR}/programs/server ]; then
   pushd ${APP_DIR}/programs/server/
   npm install
   popd
else
   echo "Unable to locate server directory; hold on: we're likely to fail"
fi

# Run meteor
cd ${APP_DIR}
exec node ./main.js
