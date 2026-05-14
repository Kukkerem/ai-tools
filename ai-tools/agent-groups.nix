{ lib, ... }:

{
  nix = import ./agents/nix/index.nix { inherit lib; };
  project = import ./agents/project/index.nix { inherit lib; };
  general = import ./agents/general/index.nix { inherit lib; };
}
