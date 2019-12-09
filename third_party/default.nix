# This file controls the import of external dependencies (i.e.
# third-party code) into my package tree.
#
# This includes *all packages needed from nixpkgs*.

{ pkgs, ... }:
let
  # The pinned commit here is identical to the public nixery.dev
  # version, since popularity data has been generated for that.
  stableCommit = "80b42e630b23052d9525840a9742100a2ceaaa8f";
  stableSrc = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs-channels/archive/${stableCommit}.tar.gz";
    sha256 = "0243qiivxl3z51biy4f5y5cy81x5bki5dazl9wqwgnmd373gpmxy";
  };
  nixpkgs = import stableSrc {
    config.allowUnfree = true;
    config.allowBroken = true;
  };

  exposed = {
    # Inherit the packages from nixpkgs that should be available inside
    # of the repo. They become available under `pkgs.third_party.<name>`
    inherit (nixpkgs)
      buildGoPackage
      cargo
      darwin
      fetchFromGitHub
      google-cloud-sdk
      haskell
      jq
      lib
      llvmPackages
      remarshal
      rsync
      runCommand
      rustc
      stdenv
      symlinkJoin
      tree
      writeShellScriptBin
      writeText;
  };

in exposed // {
  callPackage = nixpkgs.lib.callPackageWith exposed;
  # Provide the source code of nixpkgs, but do not provide an imported
  # version of it.
  nixpkgsSrc = stableSrc;
}
