{ lib, pkgs, ... }:

lib.foldl' lib.recursiveUpdate { } [
  (import ./agent-browser.nix { inherit pkgs; })
]
