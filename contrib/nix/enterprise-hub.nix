{ symlinkJoin, core, enterprise, nova, masterfiles, missionPortal, apacheHttpd, php }:

# apacheHttpd/php are included so they're on PATH/in the closure for
# whoever deploys this (a NixOS module, a container, ...) to actually run
# the hub's web UI against -- this derivation doesn't configure or start
# Apache itself, same as it doesn't start cf-serverd/cf-hub.
symlinkJoin {
  name = "cfengine-enterprise-hub";
  paths = [ core enterprise nova masterfiles missionPortal apacheHttpd php ];
}
