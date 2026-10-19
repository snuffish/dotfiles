# Terminal

Personal dotfiles and the skill registry that Claude Code and Antigravity IDE load from.

## Skill registry

**Registry**:
The source-of-truth tree of everything an agent can load or depend on: skills plus Modules.
_Avoid_: skills folder, skill library

**Skill**:
An entry a host's skill loader discovers and can invoke. Every Command, Reference and Profile is a skill; a Module is not.
_Avoid_: using "skill" for anything in the Registry regardless of kind

**Command**:
A skill that carries out a workflow, whether the user invokes it by name or by a matching request, such as `/code-review` or `squash-ef-core-migrations`. What separates it from a Reference is workflow versus knowledge, not how it is triggered.
_Avoid_: operational skill, slash command, source command

**Reference**:
A skill holding knowledge the model loads by topic, never run as a workflow, such as `modern-csharp` or `priis-backend-ef-core`.
_Avoid_: pattern skill, tech skill, reference skill

**Module**:
A shared contract that Commands depend on and that never runs on its own, such as `core` or the worktree lifecycle.
_Avoid_: core utility, protocol, shared skill, lib, root skill

**Profile**:
Project-specific facts that one Command reads to adapt itself to that project, such as the PRIIS profile read by `/implement-feature`.
_Avoid_: project config, project skill
