USE_SYSTEMD=0
_use_systemd=$(command -v systemctl 2>&1 >/dev/null && systemctl is-system-running)
case "$_use_systemd" in
  offline|unknown)
    USE_SYSTEMD=0
    ;;
  "")
    USE_SYSTEMD=0
    ;;
  *)
    USE_SYSTEMD=1
    ;;
esac

use_systemd()
{
  test $USE_SYSTEMD = 1
}

