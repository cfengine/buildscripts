{
  description = "CFEngine meta-flake: community-client, enterprise-client, enterprise-hub";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # Absolute paths required -- see the comment in
    # enterprise/contrib/nix/flake.nix for why relative "../.." doesn't
    # work here.
    core.url = "git+file:///home/victor-moene/northern.tech/cfengine/core?dir=contrib/nix";
    enterprise.url = "git+file:///home/victor-moene/northern.tech/cfengine/enterprise?dir=contrib/nix";
    nova.url = "git+file:///home/victor-moene/northern.tech/cfengine/nova?dir=contrib/nix";
    masterfiles.url = "git+file:///home/victor-moene/northern.tech/cfengine/masterfiles?dir=contrib/nix";
    mission-portal.url = "git+file:///home/victor-moene/northern.tech/cfengine/mission-portal?dir=contrib/nix";
  };

  outputs = { self, nixpkgs, flake-utils, core, enterprise, nova, masterfiles, mission-portal }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        coreOut = core.packages.${system}.default;
        enterpriseOut = enterprise.packages.${system}.default;
        novaOut = nova.packages.${system}.default;
        masterfilesOut = masterfiles.packages.${system}.default;
        missionPortalOut = mission-portal.packages.${system}.default;
      in
      {
        packages = {
          community-client = pkgs.callPackage ./community-client.nix {
            core = coreOut;
            masterfiles = masterfilesOut;
          };
          enterprise-client = pkgs.callPackage ./enterprise-client.nix {
            core = coreOut;
            enterprise = enterpriseOut;
          };
          enterprise-hub = pkgs.callPackage ./enterprise-hub.nix {
            core = coreOut;
            enterprise = enterpriseOut;
            nova = novaOut;
            masterfiles = masterfilesOut;
            missionPortal = missionPortalOut;
          };
        };
      }
    );
}
