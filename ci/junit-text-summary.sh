#!/usr/bin/env bash
# this script relies on xmlstarlet command being available.
# should generally be available via your standard package manager like sudo apt install -y xmlstarlet
if ! command -v xmlstarlet; then
  echo "$0 requires xmlstarlet command. Please install with your package manager."
  exit 1
fi
set -ex

error_log=".$$.error.log"

rm -rf "$error_log"
function error()
{
  cat "$error_log"
}
function cleanup()
{
  rm "$error_log"
}
trap error ERR
trap cleanup EXIT

if test -z "$1"; then
  echo "Usage: $0 <junit xml file>"
  exit 1
fi
if ! test -f "$1"; then
  echo "File $1 not found"
  exit 1
fi
echo "## Test Summary for $1"
xmlstarlet sel -T \
  -t -v "(/testsuites/testsuite/@tests) - (/testsuites/testsuite/@failures)" \
  -t -o " passed, " \
  -t -v "/testsuites/testsuite/@failures" \
  -t -o " failures, " \
  -t -v "sum(/testsuites/testsuite/testsuite/testsuite/@skipped)" \
  -t -o " skipped" -n \
  -t -i "//testcase/failure" \
  -t -m "//testcase/failure/.." \
  -o '- ' \
  -v "concat(@class,':',@name)" -n \
  "$1" 2>"$error_log"

# if no failures then the next command returns 1, if problem with xpath maybe exit code is 4 (man xmlstarlet gives no clues)
trap "" ERR
set +e
xmlstarlet sel -T \
  -t -i "//testcase/failure" \
  -t -m "//testcase/failure/.." \
  -v "//testcase/failure" -n \
  -t -i "//testcase/failure" \
  "$1" > "$1-failure-details.log" 2>>"$error_log"

rc=$?
if [ $rc -eq 4 ]; then
  echo "Problem with xmlstarlet command to output failure details log."
  error
  cleanup
fi
