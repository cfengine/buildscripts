#!/bin/bash

VERSION="${COMPOSER_VERSION:-2.9.5}"
INSTALL_DIR="${COMPOSER_INSTALL_DIR:-/usr/local/bin}"
PHP_PATH="${PHP_BIN:-php}"
INSTALLER="composer-installer.php"

trap 'rm -f "$INSTALLER"' EXIT

curl -fsSL https://getcomposer.org/installer -o "$INSTALLER"

# Verify checksum
EXPECTED_SIG="$(curl -fsSL https://composer.github.io/installer.sig)"
ACTUAL_SIG="$("$PHP_PATH" -r "echo hash_file('sha384', '$INSTALLER');")"
if [[ "$ACTUAL_SIG" != "$EXPECTED_SIG" ]]; then
  echo "Error: Composer installer checksum mismatch" >&2
  exit 1
fi

# Install Composer
"$PHP_PATH" "$INSTALLER" --install-dir="$INSTALL_DIR" --filename=composer --version="$VERSION"
