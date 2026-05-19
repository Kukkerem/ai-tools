{ inputs }:

let
  src = inputs.terraform-skill;
  readSkill = builtins.readFile "${src}/skills/terraform-skill/SKILL.md";
in
{
  terraform = readSkill;
}
