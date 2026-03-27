{ lib, pkgs, ... }:

lib.foldl' lib.recursiveUpdate { } [
  (import ./skills/browser/index.nix { inherit lib pkgs; })
]
