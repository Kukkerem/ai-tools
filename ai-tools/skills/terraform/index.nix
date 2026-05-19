{ inputs }:

let
  src = inputs.terraform-skill;
  readSkill = builtins.readFile "${src}/SKILL.md";
in
{
  terraform = readSkill;
}
