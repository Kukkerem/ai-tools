{ inputs }:

let
  src = inputs.mattpocock-skills;

  readSkill = category: name: builtins.readFile "${src}/skills/${category}/${name}/SKILL.md";

  engineeringSkills = {
    diagnose = readSkill "engineering" "diagnose";
    grill-with-docs = readSkill "engineering" "grill-with-docs";
    triage = readSkill "engineering" "triage";
    improve-codebase-architecture = readSkill "engineering" "improve-codebase-architecture";
    setup-matt-pocock-skills = readSkill "engineering" "setup-matt-pocock-skills";
    tdd = readSkill "engineering" "tdd";
    to-issues = readSkill "engineering" "to-issues";
    to-prd = readSkill "engineering" "to-prd";
    zoom-out = readSkill "engineering" "zoom-out";
    prototype = readSkill "engineering" "prototype";
  };

  productivitySkills = {
    grill-me = readSkill "productivity" "grill-me";
    handoff = readSkill "productivity" "handoff";
    write-a-skill = readSkill "productivity" "write-a-skill";
  };
in
engineeringSkills // productivitySkills
