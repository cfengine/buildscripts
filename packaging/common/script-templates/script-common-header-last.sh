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
