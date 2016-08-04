#!/bin/bash
# Set default settings, pull repository, build
# app, etc., _if_ we are not given a different
# command.  If so, execute that command instead.
set -e

# Default values
: ${APP_DIR:="/var/www"}      # Location of built Meteor app
: ${SRC_DIR:="/src/app"}      # Location of Meteor app source
: ${BRANCH:="master"}
: ${MONGO_URL:="mongodb://${MONGO_PORT_27017_TCP_ADDR}:${MONGO_PORT_27017_TCP_PORT}/${DB}"}
: ${PORT:="80"}
: ${RELEASE:="latest"}

export MONGO_URL
export PORT

# If we were given arguments, run them instead
if [ $? -gt 0 ]; then
   exec "$@"
fi

# If we are provided a GITHUB_DEPLOY_KEY (path), then
# change it to the new, generic DEPLOY_KEY
if [ -n "${GITHUB_DEPLOY_KEY}" ]; then
   DEPLOY_KEY=$GITHUB_DEPLOY_KEY
fi

# If we are given a DEPLOY_KEY, copy it into /root/.ssh and
# setup a github rule to use it
if [ -n "${DEPLOY_KEY}" ]; then
   if [ ! -f /root/.ssh/deploy_key ]; then
      mkdir -p /root/.ssh
      cp ${DEPLOY_KEY} /root/.ssh/deploy_key
      cat << ENDHERE >> /root/.ssh/config
Host *
  IdentityFile /root/.ssh/deploy_key
  StrictHostKeyChecking no
ENDHERE
   fi
   chmod 0600 /root/.ssh/deploy_key
fi

# Make sure critical directories exist
mkdir -p $APP_DIR
mkdir -p $SRC_DIR


# getrepo pulls the supplied git repository into $SRC_DIR
function getrepo {
   if [ -e ${SRC_DIR}/.git ]; then
      pushd ${SRC_DIR}
      echo "Updating existing local repository..."
      git fetch
      popd
   else
      echo "Cloning ${REPO}..."
      git clone ${REPO} ${SRC_DIR}
   fi

   cd ${SRC_DIR}

   echo "Switching to branch/tag ${BRANCH}..."
   git checkout ${BRANCH}

   echo "Forcing clean..."
   git reset --hard origin/${BRANCH}
   git clean -d -f
}

if [ -n "${REPO}" ]; then
   getrepo
fi

# See if we have a valid meteor source
METEOR_DIR=$(find ${SRC_DIR} -type d -name .meteor -print |head -n1)
if [ -e "${METEOR_DIR}" ]; then
   echo "Meteor source found in ${METEOR_DIR}"
   cd ${METEOR_DIR}/..

   # Check Meteor version
   echo "Checking Meteor version..."
   RELEASE=$(cat .meteor/release | cut -f2 -d'@')
   set +e # Allow the next command to fail
   semver -r '>=1.3.1' $(echo $RELEASE |cut -d'.' -f1-3)
   if [ $? -ne 0 ]; then
      echo "Application's Meteor version ($RELEASE) is less than 1.3.1; please use ulexus/meteor:legacy"
      exit 1
   fi
   set -e

   # Download Meteor installer
   echo "Downloading Meteor install script..."
   curl ${CURL_OPTS} -o /tmp/meteor.sh https://install.meteor.com/

   # Install Meteor tool
   echo "Installing Meteor ${RELEASE}..."
   sed -i "s/^RELEASE=.*/RELEASE=${RELEASE}/" /tmp/meteor.sh
   sh /tmp/meteor.sh
   rm /tmp/meteor.sh

   # Bundle the Meteor app
   echo "Building the bundle...(this may take a while)"
   mkdir -p ${APP_DIR}
   meteor build --directory ${APP_DIR}
fi

# If we were given a BUNDLE_URL, download the bundle
# from there.
if [ -n "${BUNDLE_URL}" ]; then
   echo "Downloading Application bundle from ${BUNDLE_URL}..."
   curl ${CURL_OPTS} -o /tmp/bundle.tgz ${BUNDLE_URL}
   tar xf /tmp/bundle.tgz -C ${APP_DIR}
fi

# Locate the actual bundle directory
# subdirectory (default)
if [ ! -e ${BUNDLE_DIR:=$(find ${APP_DIR} -type d -name bundle -print |head -n1)} ]; then
   # No bundle inside app_dir; let's hope app_dir _is_ bundle_dir...
   BUNDLE_DIR=${APP_DIR}
fi

# Install NPM modules
if [ -e ${BUNDLE_DIR}/programs/server ]; then
   pushd ${BUNDLE_DIR}/programs/server/

   # Check Meteor version
   echo "Checking Meteor version..."
   set +e # Allow the next command to fail
   semver -r '>=1.3.1' $(cat config.json | jq .meteorRelease | tr -d '"' | cut -f2 -d'@' | cut -d'.' -f1-3)
   if [ $? -ne 0 ]; then
      echo "Application's Meteor version is less than 1.3.1; please use ulexus/meteor:legacy"
      exit 1
   fi
   set -e

   echo "Installing NPM prerequisites..."
   # Install all NPM packages
   npm install
   popd
else
   echo "Unable to locate server directory in ${BUNDLE_DIR}; hold on: we're likely to fail"
fi

if [ ! -e ${BUNDLE_DIR}/main.js ]; then
   echo "Failed to locate main.js in ${BUNDLE_DIR}; cannot start application."
   exit 1
fi

# Run meteor
cd ${BUNDLE_DIR}
echo "Starting Meteor Application..."
exec node ./main.js
