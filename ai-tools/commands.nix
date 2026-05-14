{ inputs, lib }:

let
  commandGroups = import ./command-groups.nix { inherit inputs lib; };
in
lib.foldl' lib.recursiveUpdate { } (builtins.attrValues commandGroups)
