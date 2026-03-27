{ lib, ... }:

lib.foldl' lib.recursiveUpdate { } [
  (import ./create-prds.nix)
  (import ./generate-tasks.nix)
  (import ./process-task-list.nix)
]
