#!/usr/bin/env bash
set -e

# find the dir two levels up from here, home of all the repositories
COMPUTED_ROOT="$(readlink -e "$(dirname "$0")/../../")"
# NTECH_ROOT should be the same, but if available use it so user can do their own thing.
NTECH_ROOT=${NTECH_ROOT:-$COMPUTED_ROOT}

CORE_SHA=$(git -C "${NTECH_ROOT}/core" log --pretty='format:%h' -1 -- .)
ENTERPRISE_SHA=$(git -C "${NTECH_ROOT}/enterprise" log --pretty='format:%h' -1 -- .)
NOVA_SHA=$(git -C "${NTECH_ROOT}/nova" log --pretty='format:%h' -1 -- .)
MASTERFILES_SHA=$(git -C "${NTECH_ROOT}/masterfiles" log --pretty='format:%h' -1 -- .)
# notice below the sha is more complex, a todo is to make "code only" shas for each repo ENT-10443
MISSION_PORTAL_SHA=$(find "${NTECH_ROOT}/mission-portal" -type f -and \( -path "./application/*" -or -path "./public/*" -or -path "./phpcfenginenova/*" -or -path "./ldap/*" -or -path "./composer.json" -or -path "./package.json" -or -path "./static/*" \)  -print0 | xargs -0 sha1sum | awk '{print $1}' | sha1sum | cut -c -8)
BUILDSCRIPTS_SHA=$(find "${NTECH_ROOT}/buildscripts" -type f -and \( -path "./deps-packaging/*" -or -path "./build-scripts/*" -or -path "./packaging/*" \) -print0 | xargs -0 sha1sum | awk '{print $1}' | sha1sum | cut -c -8)

PACKAGE_SHA=$(echo "$CORE_SHA" "$ENTERPRISE_SHA" "$NOVA_SHA" "$MASTERFILES_SHA" "$MISSION_PORTAL_SHA" "$BUILDSCRIPTS_SHA" | sha256sum | cut -d' ' -f1 | cut -c -8)
echo "$PACKAGE_SHA"
