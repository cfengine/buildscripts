if [ "$(uname)" = "HP-UX" ]; then
  # /etc/profile contains tty code that won't work well when sourced and this VUE env var guards against running those bits
  # https://ftp.mirrorservice.org/sites/www.bitsavers.org/pdf/hp/9000_hpux/9.x/B1171-90044_HP_Visual_User_Environment_System_Administration_Manual_Nov91.pdf
  VUE=true
  export VUE
fi

if [ -f /etc/profile ]; then
  # running on the proxied host or not we want to make sure local customizations are taken
  # e.g. ent-14014: custom build of ssh needed for build-artifacts-cache needed and /etc/profile has PATH=/opt/craig/bin:$PATH
  . /etc/profile
fi

# while ENT-13750 is in progress we need to ensure that OTHER builds include openssl devel packages on redhat-based platforms
if command -v zypper >/dev/null 2>/dev/null; then
  sudo zypper install -y libopenssl-devel || true
fi
if command -v yum >/dev/null 2>/dev/null; then
  sudo yum install -y openssl-devel || true
fi
