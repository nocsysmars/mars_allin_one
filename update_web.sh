#!/bin/bash

BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
echo "==> 1. Download mars web code."
git clone --branch $BRANCH_NAME https://github.com/TeamNocsys/mars_web.git
if [ $? -ne 0 ]; then
 echo '==== Download Fail ===='
 exit $1
fi
echo ''
echo "==> 2. Start to build mars web code."
cd mars_web
docker run --rm -v "$PWD":/home/node/web  -w /home/node/web node:8 sh -c "npm install && npm run build:prod"
if [ $? -ne 0 ]; then
 echo '==== Build Fail ===='
 exit $1
fi
echo ''
echo "==> 3. Replace the public folder"
cd ..
rm -rf public/*
cp -r mars_web/public/* public/
rm -rf mars_web



