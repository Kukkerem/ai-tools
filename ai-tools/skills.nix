{
  inputs,
  lib,
  pkgs,
}:

lib.foldl' lib.recursiveUpdate { } [
  (import ./skills/browser/index.nix { inherit lib pkgs; })
  (import ./skills/caveman/index.nix { inherit inputs; })
  (import ./skills/dcp/index.nix { })
  (import ./skills/basic-memory/index.nix { })
  (import ./skills/notebooklm/index.nix { })
  (import ./skills/rtk/index.nix { })
  (import ./skills/gog/index.nix { inherit inputs; })
  (import ./skills/terraform/index.nix { inherit inputs; })
  (import ./skills/karpathy-guidelines/index.nix { })
  (import ./skills/mattpocock/index.nix { inherit inputs; })
  (import ./skills/superpowers/index.nix { inherit inputs; })
]
