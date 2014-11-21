case "$PKG_TYPE" in
  depot)
    alias is_upgrade='false'
    ;;
  deb)
    alias is_upgrade='native_is_upgrade'
    ;;
esac

if is_upgrade; then
  # We want to skip removal scripts on upgrade.
  exit 0
fi
