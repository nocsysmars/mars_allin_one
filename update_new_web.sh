#!/bin/bash
company=mars_prod
if [[ $1 == "ares" ]]; then
  company=ares_prod
fi

#BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
echo "==> 1. Download mars web code."
git clone --branch main https://github.com/TeamNocsys/mars_web_plus
if [ $? -ne 0 ]; then
 echo '==== Download Fail ===='
 exit $?
fi
echo ''
echo "==> 2. Start to build mars web code."
cd mars_web_plus
docker run --rm -v "$PWD":/home/node/web  -w /home/node/web node:12 sh -c "npm install -g @angular/cli && npm install && npm run build:$company"
if [ $? -ne 0 ]; then
 echo '==== Build Fail ===='
 exit $?
fi
echo ''
echo "==> 3. Replace the public folder"
cd ..

if [ ! -d "public" ]; then
  mkdir public
fi
rm -rf public/*
cp -r mars_web_plus/public/* public/
rm -rf mars_web_plus

