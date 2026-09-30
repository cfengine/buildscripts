{ symlinkJoin, core, masterfiles }:

symlinkJoin {
  name = "cfengine-community-client";
  paths = [ core masterfiles ];
}
