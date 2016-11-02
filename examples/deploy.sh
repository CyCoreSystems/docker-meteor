#!/bin/bash
# Build + Deployment script for Meteor on Kubernetes

IMAGE=ulexus/testapp
DEPLOYMENT=testapp

rm -Rf .deploy
rm -Rf build.out

# Make sure we have a starting version
if [ ! -s .version ]; then
   echo "0" > .version
fi

# Bundle Meteor
meteor build --directory .deploy/

if [ $? -ne 0 ]; then
   cat build.out
   echo -e "\033[0;31m✗ BUNDLE FAILED:\033[0m"
   exit 1
fi
echo -e "\033[0;32m✓ \033[0m \033[0;34mBUNDLED\033[0m ${DEPLOYMENT}"


# Load and increment the current version
CUR=$(( $(cat .version) + 1 ))
   
# Build the container
docker build --pull -t ${IMAGE}:v${CUR} ./ >build.out

if [ $? -ne 0 ]; then
   cat build.out
   echo -e "\033[0;31m✗ BUILD FAILED:\033[0m"
   exit 2
fi
echo -e "\033[0;32m✓ \033[0m \033[0;34mBUILT\033[0m ${IMAGE}:v${CUR}"

# Publish the container
docker push ${IMAGE}:v${CUR}

if [ $? -ne 0 ]; then
   echo -e "\033[0;31m✗ PUBLISH FAILED:\033[0m"
   exit 3
fi
echo -e "\033[0;32m✓ \033[0m \033[0;34mPUBLISHED\033[0m ${IMAGE}:v${CUR}"

echo $CUR > .version

# Update Kubernetes Deployment
kubectl --context=webapps patch deployment/${DEPLOYMENT} -p '{"spec":{"template":{"spec":{"containers":[{"name": "meteor","image":"'${IMAGE}:v${CUR}'"}]}}}}'

if [ $? -ne 0 ]; then
   echo -e "\033[0;31m✗ UPDATE FAILED:\033[0m"
   exit 4
fi
echo -e "\033[0;32m✓ \033[0m \033[0;34mUPDATED\033[0m ${IMAGE}:v${CUR}"

# Watch rollout
kubectl --context=webapps rollout status deployment/${DEPLOYMENT}

rm -Rf .deploy
exit 0
