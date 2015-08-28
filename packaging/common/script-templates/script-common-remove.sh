case `package_type` in
  rpm|deb)
    if is_upgrade; then
      # We want to skip removal scripts on upgrade.
      # However, non-rpm and non-deb package systems don't run removal scripts
      # on upgrade, so don't do it there (they would not detect upgrade
      # correctly in this situation anyway).
      exit 0
    fi
    ;;
esac
