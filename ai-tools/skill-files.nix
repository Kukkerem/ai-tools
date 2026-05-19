{
  inputs,
  lib,
  skills,
}:

let
  regularFilesRecursive =
    dir:
    let
      entries = builtins.readDir dir;
    in
    lib.concatMapAttrs (
      name: type:
      if name == "SKILL.md" then
        { }
      else if type == "regular" then
        {
          ${name}.source = "${dir}/${name}";
        }
      else if type == "directory" then
        lib.mapAttrs' (relPath: file: lib.nameValuePair "${name}/${relPath}" file) (
          regularFilesRecursive "${dir}/${name}"
        )
      else
        { }
    ) entries;

  mattpocockSrc = inputs.mattpocock-skills;
  superpowersSrc = inputs.superpowers;

  mattpocockSkillFiles =
    category: name: regularFilesRecursive "${mattpocockSrc}/skills/${category}/${name}";

  superpowersSkillFiles = name: regularFilesRecursive "${superpowersSrc}/skills/${name}";

  terraformSkillSrc = inputs.terraform-skill;
  terraformSkillFiles = regularFilesRecursive "${terraformSkillSrc}/skills/terraform-skill";

  pathBackedSkillFiles = name: regularFilesRecursive skills.${name};
in
{
  agent-browser = pathBackedSkillFiles "agent-browser";

  caveman = pathBackedSkillFiles "caveman";
  caveman-commit = pathBackedSkillFiles "caveman-commit";
  caveman-review = pathBackedSkillFiles "caveman-review";
  caveman-help = pathBackedSkillFiles "caveman-help";
  caveman-compress = pathBackedSkillFiles "caveman-compress";
  caveman-stats = pathBackedSkillFiles "caveman-stats";
  cavecrew = pathBackedSkillFiles "cavecrew";

  diagnose = mattpocockSkillFiles "engineering" "diagnose";
  grill-with-docs = mattpocockSkillFiles "engineering" "grill-with-docs";
  triage = mattpocockSkillFiles "engineering" "triage";
  improve-codebase-architecture = mattpocockSkillFiles "engineering" "improve-codebase-architecture";
  setup-matt-pocock-skills = mattpocockSkillFiles "engineering" "setup-matt-pocock-skills";
  tdd = mattpocockSkillFiles "engineering" "tdd";
  to-issues = mattpocockSkillFiles "engineering" "to-issues";
  to-prd = mattpocockSkillFiles "engineering" "to-prd";
  zoom-out = mattpocockSkillFiles "engineering" "zoom-out";
  prototype = mattpocockSkillFiles "engineering" "prototype";
  grill-me = mattpocockSkillFiles "productivity" "grill-me";
  handoff = mattpocockSkillFiles "productivity" "handoff";
  write-a-skill = mattpocockSkillFiles "productivity" "write-a-skill";

  brainstorming = superpowersSkillFiles "brainstorming";
  dispatching-parallel-agents = superpowersSkillFiles "dispatching-parallel-agents";
  executing-plans = superpowersSkillFiles "executing-plans";
  finishing-a-development-branch = superpowersSkillFiles "finishing-a-development-branch";
  receiving-code-review = superpowersSkillFiles "receiving-code-review";
  requesting-code-review = superpowersSkillFiles "requesting-code-review";
  subagent-driven-development = superpowersSkillFiles "subagent-driven-development";
  systematic-debugging = superpowersSkillFiles "systematic-debugging";
  test-driven-development = superpowersSkillFiles "test-driven-development";
  using-git-worktrees = superpowersSkillFiles "using-git-worktrees";
  using-superpowers = superpowersSkillFiles "using-superpowers";
  verification-before-completion = superpowersSkillFiles "verification-before-completion";
  writing-plans = superpowersSkillFiles "writing-plans";
  writing-skills = superpowersSkillFiles "writing-skills";

  terraform = terraformSkillFiles;
}
