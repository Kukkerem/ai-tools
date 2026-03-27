{ lib, ... }:

lib.foldl' lib.recursiveUpdate { } [
  (import ./template-designer.nix)
  (import ./system-config-expert.nix)
]
