#!/bin/bash
# Set default settings, pull repository, build
# app, etc., _if_ we are not given a different
# command.  If so, execute that command instead.
set -e

# Default values
: ${HOME:="/home/meteor"}
: ${APP_DIR:="${HOME}/www"}      # Location of built Meteor app
: ${SRC_DIR:="${HOME}/src"}      # Location of Meteor app source
: ${BRANCH:="master"}
: ${NODE_OPTIONS:=""}         # Options to pass to Node when executing app
: ${SETTINGS_FILE:=""}        # Location of settings.json file
: ${SETTINGS_URL:=""}         # Remote source for settings.json
: ${MONGO_URL:="mongodb://${MONGO_PORT_27017_TCP_ADDR}:${MONGO_PORT_27017_TCP_PORT}/${DB}"}
: ${PORT:="80"}
: ${RELEASE:="latest"}

export MONGO_URL
export PORT

# MIN_METEOR_RELEASE is the minimum Meteor version which can be run with this script
MIN_METEOR_RELEASE=1.4.0

# If we were given arguments, run them instead
if [ $? -gt 0 ]; then
   exec "$@"
fi

# If we are provided a GITHUB_DEPLOY_KEY (path), then
# change it to the new, generic DEPLOY_KEY
if [ -n "${GITHUB_DEPLOY_KEY}" ]; then
   DEPLOY_KEY=$GITHUB_DEPLOY_KEY
fi

# If we are given a DEPLOY_KEY, copy it into ${HOME}/.ssh and
# setup a github rule to use it
if [ -n "${DEPLOY_KEY}" ]; then
   if [ ! -f ${HOME}/.ssh/deploy_key ]; then
      mkdir -p ${HOME}/.ssh
      cp ${DEPLOY_KEY} ${HOME}/.ssh/deploy_key
      cat << ENDHERE >> ${HOME}/.ssh/config
Host *
  IdentityFile ${HOME}/.ssh/deploy_key
  StrictHostKeyChecking no
ENDHERE
   fi
   chmod 0600 ${HOME}/.ssh/deploy_key
fi

# Make sure critical directories exist
mkdir -p $APP_DIR
mkdir -p $SRC_DIR

function checkver {
   set +e # Allow commands inside this function to fail

   # Strip "-" suffixes
   local VER=$(echo $1 | cut -d'-' -f1)

   # Format to x.y.z
   if [ $(echo $1 | wc -c) -lt 5 ]; then
      # if version is x.y, bump it to x.y.0
      RELEASE_VER=${VER}.0
   else
      # If version is x.y.z.A, truncate it to x.y.z
      RELEASE_VER=$(echo $VER |cut -d'.' -f1-3)
   fi

   semver -r '>='$MIN_METEOR_RELEASE $RELEASE_VER >/dev/null
   if [ $? -ne 0 ]; then
      echo "Application's Meteor version ($1) is less than ${MIN_METEOR_RELEASE}; please use ulexus/meteor:legacy"

      if [ -z "${IGNORE_METEOR_VERSION}" ]; then
         exit 1
      fi
   fi

   set -e
}

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
   checkver $RELEASE

   # Download Meteor installer
   echo "Downloading Meteor install script..."
   curl ${CURL_OPTS} -o /tmp/meteor.sh https://install.meteor.com?release=${RELEASE}

   # Install Meteor tool
   echo "Installing Meteor ${RELEASE}..."
   sh /tmp/meteor.sh
   rm /tmp/meteor.sh

   if [ -f package.json ]; then
      echo "Installing application-side NPM dependencies..."
      meteor npm install --production
   fi

   # Bundle the Meteor app
   echo "Building the bundle...(this may take a while)"
   mkdir -p ${APP_DIR}
   meteor build --directory ${APP_DIR}
fi

# If we were given a BUNDLE_FILE, extract the bundle
# from there.
if [ -n "${BUNDLE_FILE}" ]; then
   tar xf ${BUNDLE_FILE} -C ${APP_DIR}
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
   set +e # Allow the next commands to fail
   checkver $(cat config.json | jq -r .meteorRelease | cut -f2 -d'@')

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

# Process settings sources, if they exist
if [ -f "${SETTINGS_FILE}" ]; then
   export METEOR_SETTINGS=$(cat ${SETTINGS_FILE})
fi
if [ "x${SETTINGS_URL}" != "x" ]; then
   TMP_SETTINGS=$(curl -s ${SETTINGS_URL})
   if [ $? -eq 0 ]; then
      export METEOR_SETTINGS=${TMP_SETTINGS}
   else
      echo "Failed to retrieve settings from URL (${SETTINGS_URL}); exiting."
      exit 1
   fi
fi

# Run meteor
cd ${BUNDLE_DIR}
echo "Starting Meteor Application..."
exec node ${NODE_OPTIONS} ./main.js
