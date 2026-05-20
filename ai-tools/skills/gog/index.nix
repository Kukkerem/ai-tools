{ inputs }:

let
  src = inputs.nix-openclaw-tools;
  readSkill = builtins.readFile "${src}/tools/gogcli/skills/gog/SKILL.md";
in
{
  gog = readSkill;
}
