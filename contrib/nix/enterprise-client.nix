{ symlinkJoin, core, enterprise }:

# Deliberately no masterfiles here: an enterprise agent gets its policy
# from the hub it's bootstrapped to, unlike the standalone community
# agent, which ships default policy to bootstrap itself.
symlinkJoin {
  name = "cfengine-enterprise-client";
  paths = [ core enterprise ];
}
