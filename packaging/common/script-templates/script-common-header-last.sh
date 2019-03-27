if [ -f "$PREFIX/CFENGINE_TEST_PACKAGE_SCRIPT.txt" ]; then
  # Special mode during testing. Dump some info for verification.
  (
    echo "new_script----"
    echo "script_type=$SCRIPT_TYPE"
    if is_upgrade; then
      echo "is_upgrade=1"
    else
      echo "is_upgrade=0"
    fi
  ) >> "$PREFIX/CFENGINE_TEST_PACKAGE_SCRIPT.log"
fi

is_community()
{
  test "$PROJECT_TYPE" = "cfengine-community"
}

is_nova()
{
  test "$PROJECT_TYPE" = "cfengine-nova" || test "$PROJECT_TYPE" = "cfengine-nova-hub"
}

INSTLOG=/var/log/CFEngineHub-Install.log
mkdir -p "$(dirname "$INSTLOG")"
touch "$INSTLOG"
chown root:root "$INSTLOG"
chmod 600 "$INSTLOG"
CONSOLE=7
# Redirect most output to log file, but keep console around for custom output.
case "$SCRIPT_TYPE" in
  pre*)
    eval "exec $CONSOLE>&1 > $INSTLOG 2>&1"
    ;;
  *)
    eval "exec $CONSOLE>&1 >> $INSTLOG 2>&1"
    ;;
esac
echo "$SCRIPT_TYPE:"

# Output directly to console, bypassing log.
cf_console()
{
  # Use subshell to prevent "set +x" from leaking out into the rest of the
  # execution.
  (
    set +x
    "$@" 1>&$CONSOLE 2>&$CONSOLE
  )
}

set -x
