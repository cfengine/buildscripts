# cfengine-nova.rb
#
# Homebrew Formula for the CFEngine Enterprise Nova *client* (the "non-hub"
# / agent role: cf-agent, cf-execd, cf-serverd, cf-monitord, etc. -- no
# Mission Portal, no Postgres, no cf-hub).
#
# This formula is a macOS-native re-expression of the build that
# buildscripts/build-scripts/{autogen,install-dependencies,configure,compile}
# already performs for Linux/AIX/Solaris/HP-UX/FreeBSD, run with:
#
#   PROJECT=nova EXPLICIT_ROLE=agent BUILD_TYPE=RELEASE
#
# WHY IT DOESN'T JUST SHELL OUT TO install-dependencies:
# That script builds each dependency by calling
# `buildscripts/deps-packaging/pkg-build-$DEP_PACKAGING` (deb/rpm/freebsd/
# hpux/solaris) and installing the result with `pkg-install-$DEP_PACKAGING`.
# There is no "darwin"/homebrew flavor of that native-package machinery
# (see buildscripts/build-scripts/detect-environment's detect_arch, which
# has no Darwin case and would exit 42). Adding one is a bigger project
# (a whole pkg-build-darwin/pkg-find-darwin/pkg-install-darwin/pkg-cache
# flavor). Instead, this formula builds the same pinned dependency sources
# (see buildscripts/deps-packaging/*/distfiles and *.spec.in, which remain
# the source of truth -- keep the versions/checksums/flags below in sync
# with those files) directly, the way a Homebrew formula normally builds
# its resources, and then drives core/enterprise/masterfiles' own
# `./configure` + `make install` (the same configure invocation
# buildscripts/build-scripts/configure constructs).
#
# KNOWN GAPS / TODO
#   - CFEngine's traditional WORKDIR (policy/state/keys) is kept outside
#     the versioned Cellar keg (in HOMEBREW_PREFIX/var/cfengine) so it
#     survives `brew upgrade`, unlike every other CFEngine platform
#     package, which uses one fixed, non-versioned prefix for everything.
#     This is new territory for CFEngine packaging -- validate it holds up
#     to a real upgrade before relying on it in production.
#   - Only the two darwin-agnostic openssl patches (0006, 0008) are
#     applied, mirroring what cfbuild-openssl.spec applies unconditionally
#     on every platform; patch 0009 (Solaris-only) is skipped, matching
#     that spec.
#   - No native ACL/xattr support (libacl/libattr, Linux-only deps) is
#     built; macOS has its own ACL/xattr APIs which core's C code already
#     handles via its own platform code, independent of this dependency.
#   - This formula has been written and syntax-checked but NOT build-tested
#     end to end on real macOS hardware.
class CfengineNova < Formula
  desc "CFEngine Enterprise Nova client (non-hub/agent role): cf-agent and friends"
  homepage "https://cfengine.com"
  license "COSL"

  # buildscripts itself is what we "distribute" -- it's the thing that
  # knows how to turn core+enterprise+masterfiles into a running agent.
  url "https://github.com/cfengine/buildscripts.git", branch: "master"
  version "3.29.0"
  head "https://github.com/cfengine/buildscripts.git", branch: "master"

  # --- CFEngine repositories (kept side by side, as build-scripts expects) ---

  resource "core" do
    url "https://github.com/cfengine/core.git", branch: "master"
  end

  resource "enterprise" do
    # Private repo. `brew install` shells out to plain `git clone`, so this
    # works wherever the invoking user/CI already has SSH access configured
    # (an ssh-agent with a deploy key, a personal key in ~/.ssh, etc). There
    # is deliberately no token/credential handling here.
    url "git@github.com:cfengine/enterprise.git", branch: "master", using: :git
  end

  resource "masterfiles" do
    url "https://github.com/cfengine/masterfiles.git", branch: "master"
  end

  # --- Vendored (statically bundled) dependencies ---
  #
  # Versions/checksums/configure flags below are transcribed from, and must
  # be kept in sync with:
  #   buildscripts/deps-packaging/<dep>/distfiles   (version + sha256)
  #   buildscripts/deps-packaging/<dep>/source      (download URL prefix)
  #   buildscripts/deps-packaging/<dep>/cfbuild-<dep>.spec  (configure flags)
  #   buildscripts/deps-packaging/openssl/config_flags_agent.txt

  resource "dep-zlib" do
    url "https://zlib.net/fossils/zlib-1.3.2.tar.gz"
    sha256 "bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16"
  end

  resource "dep-openssl" do
    url "https://github.com/openssl/openssl/releases/download/openssl-4.0.1/openssl-4.0.1.tar.gz"
    sha256 "2db3f3a0d6ea4b59e1f094ace2c8cd536dffb87cdc39084c5afa1e6f7f37dd09"
  end

  resource "dep-pcre2" do
    url "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.47/pcre2-10.47.tar.gz"
    sha256 "c08ae2388ef333e8403e670ad70c0a11f1eed021fd88308d7e02f596fcd9dc16"
  end

  resource "dep-lmdb" do
    url "https://git.openldap.org/openldap/openldap/-/archive/LMDB_1.0.1/openldap-LMDB_1.0.1.tar.gz"
    sha256 "63a3cdcca69f4fd403b61fd5c5a51a119f1549d7b375b33f624e64df2933d336"
  end

  resource "dep-librsync" do
    url "https://github.com/librsync/librsync/releases/download/v2.3.4/librsync-2.3.4.tar.gz"
    sha256 "a0dedf9fff66d8e29e7c25d23c1f42beda2089fb4eac1b36e6acd8a29edfbd1f"
  end

  resource "dep-libcurl" do
    url "https://curl.se/download/curl-8.21.0.tar.gz"
    sha256 "d9b327997999045a24cda50f3983e69e51c516bd8be6ef9842fc7f99135e33bb"
  end

  # leech2 is NOT optional -- enterprise/configure.ac fails outright
  # (`leech2 is required by enterprise`) without it. It's a Rust crate
  # (cargo build --release), unlike the rest of the vendored deps.
  resource "dep-leech2" do
    url "https://github.com/larsewi/leech2/releases/download/v5.4.4/leech2-5.4.4.tar.gz"
    sha256 "3af85af5620cbe400b42c550bd4da72c1b57b39ede33e171bac27001dc7e5c6f"
  end

  # --- Build-time tools ---
  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "bison" => :build
  depends_on "flex" => :build
  depends_on "rust" => :build # leech2 is a Rust crate

  # bison/flex from Homebrew (not the outdated /usr/bin versions Xcode ships)
  # need to be ahead of the system ones on PATH; Homebrew's `depends_on`
  # keg-only handling takes care of that for us at build time.

  def install
    ENV["PROJECT"] = "nova"
    ENV["EXPLICIT_ROLE"] = "agent"
    ENV["BUILD_TYPE"] = "RELEASE"

    # A single vendor tree, exactly like BUILDPREFIX on every other CFEngine
    # platform package: core/enterprise configure against this via
    # --with-openssl=..., --with-pcre2=..., etc, and it ends up shipped
    # inside the keg (lib/) alongside the CFEngine libraries/binaries.
    vendor = buildpath/"vendor"
    vendor.mkpath

    build_vendored_deps(vendor)
    build_cfengine(vendor)
  end

  # Builds zlib, openssl, pcre2, lmdb, librsync and libcurl from the same
  # pinned sources CFEngine's other packages use, installing them all into
  # one prefix (`vendor`) the way BUILDPREFIX does for the deb/rpm/etc
  # packages built by buildscripts/build-scripts/install-dependencies.
  def build_vendored_deps(vendor)
    rpath_ldflags = "-Wl,-rpath,#{vendor}/lib"

    resource("dep-zlib").stage do
      system "./configure", "--prefix=#{vendor}"
      system "make"
      system "make", "install"
    end

    resource("dep-openssl").stage do
      # These are the two patches cfbuild-openssl.spec applies
      # unconditionally (Patch0/Patch1); the third patch in the directory
      # (0009, Solaris SPARC _XOPEN_SOURCE) is Solaris-only and is not
      # applied by that spec either.
      patch_dir = buildpath/"deps-packaging/openssl"
      system "patch", "-p1", "-i", patch_dir/"0006-Add-latomic-on-AIX-7.patch"
      system "patch", "-p1", "-i", patch_dir/"0008-Define-_XOPEN_SOURCE_EXTENDED-as-1.patch"

      global_flags = (patch_dir/"config_flags_agent.txt").read.split
      target = Hardware::CPU.arm? ? "darwin64-arm64-cc" : "darwin64-x86_64-cc"

      system "perl", "./Configure", target, *global_flags,
             "--prefix=#{vendor}", "--libdir=lib", rpath_ldflags
      system "make", "depend"
      system "make"
      system "make", "install_sw"
      system "make", "install_ssldirs"
    end

    resource("dep-pcre2").stage do
      system "./configure", "--prefix=#{vendor}", "--enable-shared", "--disable-static",
             "LDFLAGS=#{rpath_ldflags}"
      system "make"
      system "make", "install"
    end

    resource("dep-lmdb").stage do
      # cfbuild-lmdb.spec applies every 00*.patch with `patch -p3` against
      # the liblmdb subdirectory of the openldap tarball. Homebrew's `stage`
      # already flattens the tarball's single top-level directory (the
      # openldap-LMDB_1.0.1/ the spec's `%setup -q -n ...` lands in), so
      # "libraries/liblmdb" -- not "openldap-LMDB_1.0.1/libraries/liblmdb"
      # -- is the right path from here.
      liblmdb = Pathname.pwd/"libraries/liblmdb"
      Dir[buildpath/"deps-packaging/lmdb/00*.patch"].sort.each do |p|
        system "patch", "-p3", "-d", liblmdb, "-i", p
      end
      cd liblmdb do
        system "./configure", "--prefix=#{vendor}", "--libdir=#{vendor}/lib",
               "LDFLAGS=#{rpath_ldflags}"
        system "make"
        system "make", "install"
      end
    end

    resource("dep-librsync").stage do
      Dir[buildpath/"deps-packaging/librsync/00*.patch"].sort.each do |p|
        system "patch", "-p1", "-i", p
      end
      system "chmod", "+x", "ar-lib", "compile", "config.guess", "config.sub",
             "configure", "depcomp", "install-sh", "libtool", "ltmain.sh", "missing"
      system "./configure", "--prefix=#{vendor}", "--enable-shared", "--disable-static",
             "LDFLAGS=#{rpath_ldflags}"
      system "make"
      system "make", "install"
    end

    resource("dep-libcurl").stage do
      system "./configure",
             "--with-ssl=#{vendor}",
             "--with-zlib=#{vendor}",
             "--disable-ldap",
             "--disable-ldaps",
             "--disable-ntlm",
             "--without-gnutls",
             "--without-gssapi",
             "--without-libpsl",
             "--without-librtmp",
             "--without-libssh2",
             "--without-nghttp2",
             "--without-winidn",
             "--prefix=#{vendor}",
             "CPPFLAGS=-I#{vendor}/include",
             "LDFLAGS=#{rpath_ldflags}"
      system "make"
      system "make", "install"
    end

    resource("dep-leech2").stage do
      ENV["RUSTFLAGS"] = "-C link-arg=-Wl,-rpath,#{vendor}/lib"
      system "cargo", "build", "--release"

      vendor_bin = vendor/"bin"
      vendor_lib = vendor/"lib"
      vendor_pc = vendor/"lib/pkgconfig"
      vendor_inc = vendor/"include"
      [vendor_bin, vendor_lib, vendor_pc, vendor_inc].each(&:mkpath)

      # cfbuild-leech2.spec expects target/release/libleech2.so (Linux); the
      # same cdylib crate target produces libleech2.dylib on macOS.
      built_lib = Pathname.pwd.glob("target/release/libleech2.{so,dylib}").first
      odie "leech2: couldn't find built libleech2.{so,dylib}" if built_lib.nil?
      vendor_lib.install built_lib
      vendor_bin.install "target/release/lch"
      vendor_inc.install "include/leech2.h"

      pc = (Pathname.pwd/"leech2.pc.in").read
      pc = pc.sub("@LIBDIR@", "lib").sub("@VERSION@", "5.4.4").sub(/^prefix=.*$/, "prefix=#{vendor}")
      (vendor_pc/"leech2.pc").write pc
    end
  end

  # Lays out core, enterprise and masterfiles side by side (as
  # buildscripts/build-scripts/{autogen,configure,compile} expect) and runs
  # the same configure/make/make-install steps those scripts run, with
  # --prefix/--with-workdir split so upgrades don't wipe local state (see
  # the class-level TODO note about this).
  def build_cfengine(vendor)
    root = buildpath.parent/"cfe-root"
    root.mkpath
    resource("core").stage(root/"core")
    resource("enterprise").stage(root/"enterprise")
    resource("masterfiles").stage(root/"masterfiles")

    workdir = var/"cfengine"

    common_args = %W[
      --libdir=#{lib}
      --sysconfdir=#{etc}
      --with-openssl=#{vendor}
      --with-pcre2=#{vendor}
      --with-lmdb=#{vendor}
      --with-librsync=#{vendor}
      --with-libcurl=#{vendor}
      --without-cfmod
      --without-postgresql
      --without-libxml2
      --without-libyaml
      --without-libvirt
      --without-libacl
      --without-systemd-service
    ]

    ldflags = "-Wl,-rpath,#{vendor}/lib -Wl,-rpath,#{lib}"

    cd root/"core" do
      system "./autogen.sh" if File.exist?("autogen.sh") && !File.exist?("configure")
      system "./configure", "--prefix=#{prefix}", "--with-workdir=#{workdir}", *common_args,
             "LDFLAGS=#{ldflags}"
      system "make"
      system "make", "install"
    end

    cd root/"enterprise" do
      system "./autogen.sh" if File.exist?("autogen.sh") && !File.exist?("configure")
      # --with-leech2 is not optional: enterprise/configure.ac hard-errors
      # ("leech2 is required by enterprise") without it. --without-ldap is
      # enterprise-only (core has no such flag; LDAP policy functions are
      # an optional enterprise feature, auto-detected/"check" by default,
      # so we turn it off explicitly rather than risk picking up macOS's
      # own LDAP framework).
      system "./configure", "--prefix=#{prefix}", "--with-workdir=#{workdir}",
             "--with-core=#{root/"core"}", "--with-leech2=#{vendor}", "--without-ldap",
             *common_args, "LDFLAGS=#{ldflags}"
      system "make"
      system "make", "install"
    end

    cd root/"masterfiles" do
      system "./autogen.sh" if File.exist?("autogen.sh") && !File.exist?("configure")
      system "./configure", "--prefix=#{prefix}", "--with-workdir=#{workdir}"
      system "make", "install"
    end

    # Ship the vendored libs (openssl/pcre2/lmdb/librsync/curl/zlib) inside
    # the keg too, same as every other CFEngine platform package bundles
    # them -- cf-agent et al are linked against them via the rpath above.
    lib.install Dir[vendor/"lib/*.dylib*"]
  end

  service do
    run [opt_bin/"cf-execd", "--no-fork"]
    keep_alive true
    log_path var/"log/cfengine/cf-execd.log"
    error_log_path var/"log/cfengine/cf-execd.log"
    working_dir var/"cfengine"
  end

  def caveats
    <<~EOS
      CFEngine's policy/state directory (WORKDIR) is kept at:
        #{var}/cfengine
      separate from this keg, so it survives `brew upgrade`. Bootstrap with:
        #{opt_bin}/cf-agent --bootstrap <hub-address>

      This is a new arrangement for CFEngine packaging (every other platform
      package uses one fixed prefix for both binaries and state) -- please
      validate it across an actual upgrade before relying on it.

      `enterprise` is a private repository: building this formula requires
      SSH access to git@github.com:cfengine/enterprise.git from this machine
      (or CI runner).
    EOS
  end

  test do
    system bin/"cf-agent", "--version"
  end
end
