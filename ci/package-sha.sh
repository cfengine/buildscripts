#!/usr/bin/env bash
set -e

# find the dir two levels up from here, home of all the repositories
COMPUTED_ROOT="$(readlink -e "$(dirname "$0")/../../")"
# NTECH_ROOT should be the same, but if available use it so user can do their own thing.
NTECH_ROOT=${NTECH_ROOT:-$COMPUTED_ROOT}

CORE_SHA=$(git -C "${NTECH_ROOT}/core" log --pretty='format:%h' -1 -- .)
echo "CORE_SHA: ${CORE_SHA}" >&2
ENTERPRISE_SHA=$(git -C "${NTECH_ROOT}/enterprise" log --pretty='format:%h' -1 -- .)
echo "ENTERPRISE_SHA: ${ENTERPRISE_SHA}" >&2
NOVA_SHA=$("${NTECH_ROOT}/nova/ci/code-sha.sh")
echo "NOVA_SHA: ${NOVA_SHA}" >&2
MASTERFILES_SHA=$(git -C "${NTECH_ROOT}/masterfiles" log --pretty='format:%h' -1 -- .)
echo "MASTERFILES_SHA: ${MASTERFILES_SHA}" >&2
# notice below the sha is more complex, a todo is to make "code only" shas for each repo ENT-10443
MISSION_PORTAL_SHA=$(find "${NTECH_ROOT}/mission-portal" -type f -and \( -path "*/mission-portal/application/*" -or -path "*/mission-portal/public/*" -or -path "*/mission-portal/phpcfenginenova/*" -or -path "*/mission-portal/ldap/*" -or -path "*/mission-portal/composer.json" -or -path "*/mission-portal/package.json" -or -path "*/mission-portal/static/*" \)  -print0 | xargs -0 sha1sum | awk '{print $1}' | sha1sum | cut -c -8)
echo "MISSION_PORTAL_SHA: ${MISSION_PORTAL_SHA}" >&2
BUILDSCRIPTS_SHA=$(find "${NTECH_ROOT}/buildscripts" -type f -and \( -path "*/deps-packaging/*"-or -path "*/build-scripts/*" -or -path "*/packaging/*" \) -print0 | xargs -0 sha1sum | awk '{print $1}' | sha1sum | cut -c -8)
echo "BUILDSCRIPTS_SHA: ${BUILDSCRIPTS_SHA}" >&2

PACKAGE_SHA=$(echo "$CORE_SHA" "$ENTERPRISE_SHA" "$NOVA_SHA" "$MASTERFILES_SHA" "$MISSION_PORTAL_SHA" "$BUILDSCRIPTS_SHA" | sha256sum | cut -d' ' -f1 | cut -c -8)
echo "$PACKAGE_SHA"
