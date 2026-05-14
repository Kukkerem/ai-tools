{ inputs, lib }:

{
  nix = import ./commands/nix/index.nix { inherit lib; };
  git = import ./commands/git/index.nix { inherit lib; };
  quality = import ./commands/quality/index.nix { inherit lib; };
  project = import ./commands/project/index.nix { inherit lib; };
  prd = import ./commands/prd/index.nix { inherit lib; };
  caveman = import ./commands/caveman/index.nix { inherit inputs lib; };
}
