#!/bin/bash

read -p 'branch (main; accton; sia; vcmy): ' BRANCH

case $BRANCH in
     accton) read -p 'brand name (mars; ares): ' BRAND
	     case $BRAND in
		     mars) BRAND="mars_prod" ;;
                     ares) BRAND="ares_prod" ;;
		     *) echo "Wrong brand name, only mars or ares"; exit;;
             esac
	     ;;
     main) read -p 'brand name (mars; ares): ' BRAND
             case $BRAND in
                     mars) BRAND="mars_prod" ;;
                     ares) BRAND="ares_prod" ;;
                     *) echo "Wrong brand name, only mars or ares"; exit;;
             esac
             ;;
     sia)
	    read -p 'brand name (sia; crsc): ' BRAND
	    case $BRAND in
		    sia)  BRAND="sia_prod" ;;
		    crsc) BRAND="crsc_prod" ;;
		    *) echo "Wrong brand name only sia, crsc";;
	    esac
	     ;;
     vcmy) BRAND="vcmy_prod"
	     ;;
     main)
         case $BRAND in
             mars) BRAND="mars_prod" ;;
                     ares) BRAND="ares_prod" ;;
             *) echo "Wrong brand name, only mars or ares"; exit;;
             esac
         ;;
     *)
	echo "Wrong Branch Name"
	exit;;
esac

echo "==> 1. Download mars web code."
rm -rf mars_web_plus
git clone --depth=1 --branch $BRANCH https://github.com/TeamNocsys/mars_web_plus
if [ $? -ne 0 ]; then
 echo '==== Download Fail ===='
 exit $?
fi
echo ''
echo "==> 2. Start to build mars web code."
cd mars_web_plus
docker run --rm -v "$PWD":/home/node/web  -w /home/node/web node:12 sh -c "npm install -g @angular/cli && npm install && npm run build:$BRAND"
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
#rm -rf mars_web_plus
echo "Branch $BRAND, branch is $BRANCH"
