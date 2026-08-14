{ inputs }:

let
  src = inputs.mattpocock-skills;

  readSkill = category: name: builtins.readFile "${src}/skills/${category}/${name}/SKILL.md";

  engineeringSkills = {
    diagnose = readSkill "engineering" "diagnosing-bugs";
    grill-with-docs = readSkill "engineering" "grill-with-docs";
    triage = readSkill "engineering" "triage";
    improve-codebase-architecture = readSkill "engineering" "improve-codebase-architecture";
    setup-matt-pocock-skills = readSkill "engineering" "setup-matt-pocock-skills";
    tdd = readSkill "engineering" "tdd";
    to-tickets = readSkill "engineering" "to-tickets";
    to-spec = readSkill "engineering" "to-spec";
    prototype = readSkill "engineering" "prototype";
  };

  productivitySkills = {
    grill-me = readSkill "productivity" "grill-me";
    handoff = readSkill "productivity" "handoff";
    writing-for-agents = readSkill "productivity" "writing-for-agents";
  };
in
engineeringSkills // productivitySkills
