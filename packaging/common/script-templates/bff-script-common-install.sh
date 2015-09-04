if [ "$SCRIPT_TYPE" = preinstall ]; then
  if [ -f "$PREFIX/AIX_PREINSTALL_ALREADY_DONE.txt" ]; then
    # This means we have been called before, indicating that the previous run
    # was pre_rm, and this is pre_i. In this case we should not run at all.
    rm -f "$PREFIX/AIX_PREINSTALL_ALREADY_DONE.txt"
    exit 0
  else
    # Else we are in pre_rm if this is an upgrade, or in pre_i, if this is an
    # install. This mean we must create the helper file, since it is only way to
    # tell later that pre_rm has already been run. It will be cleaned up in
    # postinstall.
    echo "Helper file used by CFEngine package installation. Can be safely deleted." > "$PREFIX/AIX_PREINSTALL_ALREADY_DONE.txt"
  fi
elif [ "$SCRIPT_TYPE" = postinstall ]; then
  # See above.
  rm -f "$PREFIX/AIX_PREINSTALL_ALREADY_DONE.txt"
fi
