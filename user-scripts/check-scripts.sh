#!/bin/bash -e

#
# Interactively lint & format shell scripts in the build-scripts directory.
#
# Dependencies:
# * shfmt
# * shellcheck
#
# This script takes no arguments can be executed from anywhere, e.g.:
# $ ./user-scripts/check-scripts.sh
#

BUILD_SCRIPTS="$(dirname "$0")"/../build-scripts

grep -Erl '^(#!/(bin|usr/bin)/(env )?(sh|bash))' "$BUILD_SCRIPTS" | sort | while read -r filepath; do
    filename=$(basename "$filepath")

    if ! shfmt --diff --indent=4 "$filepath"; then
        echo
        echo "File '$filename' requires formatting."
        read -r -p "Do you wish to format '$filename'? [y/N] " answer </dev/tty
        case $answer in
        [yY] | [yY][eE][sS])
            echo "Formatting file '$filename'..."
            shfmt --write --indent=4 "$filepath"
            ;;
        *)
            echo "Skipping formatting of file '$filename'..."
            ;;
        esac
    fi

    if ! shellcheck --external-sources --source-path="$BUILD_SCRIPTS" "$filepath"; then
        echo
        echo "File '$filename' requires manual intervention."
        read -n 1 -s -r -p "Press any key to continue..." </dev/tty
        echo
    fi
done
