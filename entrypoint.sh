#!/bin/bash
# Set default settings, pull repository, build
# app, etc., _if_ we are not given a different
# command.  If so, execute that command instead.
set -e

# Default values
: ${APP_DIR:="/var/www"}      # Location of built Meteor app
: ${SRC_DIR:="/src/app"}      # Location of Meteor app source
: ${BRANCH:="master"}
: ${SETTINGS_FILE:=""}        # Location of settings.json file
: ${SETTINGS_URL:=""}         # Remote source for settings.json
: ${MONGO_URL:="mongodb://${MONGO_PORT_27017_TCP_ADDR}:${MONGO_PORT_27017_TCP_PORT}/${DB}"}
: ${PORT:="80"}
: ${RELEASE:="latest"}

export MONGO_URL
export PORT

# If we were given arguments, run them instead
if [ $? -gt 1 ]; then
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

   # Download Meteor installer
   echo "Downloading Meteor install script..."
   curl ${CURL_OPTS} -o /tmp/meteor.sh https://install.meteor.com/

   # Install Meteor tool
   echo "Installing Meteor ${RELEASE}..."
   if [ "$RELEASE" != "latest" ]; then
     sed -i "s/^RELEASE=.*/RELEASE=${RELEASE}/" /tmp/meteor.sh
   fi
   sh /tmp/meteor.sh
   rm /tmp/meteor.sh

   # Bundle the Meteor app
   echo "Building the bundle...(this may take a while)"
   mkdir -p ${APP_DIR}
   set +e # Allow the next command to fail
   meteor build --directory ${APP_DIR}
   if [ $? -ne 0 ]; then
      echo "Building the bundle (old version)..."
      set -e
      # Old versions used 'bundle' and didn't support the --directory option
      meteor bundle bundle.tar.gz
      tar xf bundle.tar.gz -C ${APP_DIR}
   fi
   set -e
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
   echo "Installing NPM prerequisites..."
   pushd ${BUNDLE_DIR}/programs/server/

   # Use a version of fibers which has a binary
   mv npm-shrinkwrap.json old-shrinkwrap.json
   cat old-shrinkwrap.json |jq -r 'setpath(["dependencies","fibers","resolved"]; "https://registry.npmjs.org/fibers/-/fibers-1.0.7.tgz")' > npm-shrinkwrap.json

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
if [ -f ${SETTINGS_FILE} ]; then
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
exec node ./main.js
