# NixOS module that wires the ai-tools Home Manager module into a NixOS system
# that already imports home-manager as a NixOS module.
#
# Usage (in your NixOS configuration):
#
#   imports = [
#     inputs.ai-tools.nixosModules.default
#   ];
#
# This makes `programs.ai-tools` available inside every
# `home-manager.users.<name>` block without having to wire the HM module
# yourself. The ai-tools HM module is still opt-in per user:
#
#   home-manager.users.alice = {
#     programs.ai-tools.enable = true;
#   };
#
# Note: this module requires home-manager to be imported as a NixOS module
# (i.e. `inputs.home-manager.nixosModules.home-manager` in your imports).
# Standalone home-manager users should use `homeManagerModules.default` instead.
{ inputs }:
{ ... }:
{
  home-manager.sharedModules = [
    (import ../home-manager { inherit inputs; })
  ];
}
