#!/usr/bin/env bash

echo "=== tool versions (npm, node, composer) ==="
which npm
npm --version
which node
node --version
which composer
composer --version

set -ex
(
if test -f "mission-portal/public/scripts/package.json"; then
	cd mission-portal/public/scripts
	# install dependencies from npmjs
	npm ci
	# build react components
	npm run build
	# remove the packages specified in devDependencies
	npm prune --omit=dev
fi
)

# install composer and friends
(
if test -f "mission-portal/composer.json"; then
	cd mission-portal
	# install PHP dependencies from composer
	composer install --no-dev
fi
)

(
if test -f "nova/api/http/composer.json"; then
	cd nova/api/http/
	# install PHP dependencies from composer
	composer install --ignore-platform-reqs --no-dev
fi
)

(
if test -f "mission-portal/public/themes/default/bootstrap/cfengine_theme.less"; then
	cd mission-portal/public/themes/default/bootstrap
	npx -p less lessc --compress ./cfengine_theme.less ./compiled/css/cfengine.less.css
fi
)

(
if test -f "mission-portal/ldap/composer.json"; then
	cd mission-portal/ldap
	# install PHP dependencies from composer
	composer install --no-dev
fi
)

# packages needed for autogen are installed in setup.sh
NO_CONFIGURE=1 PROJECT=nova ./buildscripts/build-scripts/autogen

# remove unwanted dependencies
sudo apt-get -qy purge libltdl-dev libltdl7 #libtool
