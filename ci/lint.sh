#!/usr/bin/env bash
shellcheck_dirs() {
  grep -Erl '^(#!/(bin|usr/bin)/(env )?(sh|bash))' "$1" | while read -r file; do
      shellcheck --external-sources --source-path=build-scripts "$file"
  done
}

shellcheck_dirs build-scripts/

# some dirs are "dirty" aka need some work so don't fail on those yet
shellcheck_dirs ci/ packaging/ || true
