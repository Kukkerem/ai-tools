{ inputs }:

let
  src = inputs.superpowers;
  skillsDir = "${src}/skills";

  readSkill = name: builtins.readFile "${skillsDir}/${name}/SKILL.md";
in
{
  brainstorming = readSkill "brainstorming";
  dispatching-parallel-agents = readSkill "dispatching-parallel-agents";
  executing-plans = readSkill "executing-plans";
  finishing-a-development-branch = readSkill "finishing-a-development-branch";
  receiving-code-review = readSkill "receiving-code-review";
  requesting-code-review = readSkill "requesting-code-review";
  subagent-driven-development = readSkill "subagent-driven-development";
  systematic-debugging = readSkill "systematic-debugging";
  test-driven-development = readSkill "test-driven-development";
  using-git-worktrees = readSkill "using-git-worktrees";
  using-superpowers = readSkill "using-superpowers";
  verification-before-completion = readSkill "verification-before-completion";
  writing-plans = readSkill "writing-plans";
  writing-skills = readSkill "writing-skills";
}
