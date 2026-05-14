{ lib, ... }:

let
  agentGroups = import ./agent-groups.nix { inherit lib; };
in
lib.foldl' lib.recursiveUpdate { } (builtins.attrValues agentGroups)
