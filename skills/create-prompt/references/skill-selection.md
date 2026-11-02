# Skill Selection & Syntax Grounding

Rules and priority hierarchy for selecting the right target skill and grounding its syntax.

---

## 1. Candidate Selection Hierarchy

1. **Available listing**: Select exclusively from currently available skills in the session listing. Shortlist the 2–3 skills whose descriptions best match the user's intent.
2. **Inspect shortlisted definitions**: Read frontmatter, headings, and options of candidate `SKILL.md` files. Built-in skills without readable files rely on their listing description.
3. **Selection rules (in order)**:
   - **Authoritative redirection**: A skill's explicit "Not for X (use /y)" instruction is final. If it redirects, follow the pointer.
   - **Primary purpose**: The intended action must be the skill's primary job, not a secondary feature or incidental capability.
   - **Specificity & profiles**: In projects with custom skills, prefer the most specific skill covering the action. If a general command pairs with a `<command>-<project>-profile`, invoke the general command; it loads the profile automatically.
   - **Command vs. reference**: Reference skills (conventions, domain patterns, rulebooks) are never invoked as the command. Name them in the prompt's `Rules:` line instead.
   - **Outward actions**: Actions with external blast radius (commit, push, open PR, publish comments, mutate tracker items) appear only if the user explicitly requested them. Otherwise, terminate the prompt prior to outward actions.
   - **Plain prompt fallback**: If no skill genuinely fits, write a clean prompt without a skill slash-command. Never force an ill-fitting skill.

---

## 2. Syntax & Argument Grounding

- **Exact syntax**: Use the target skill's documented `argument-hint` and valid modifiers (`--deep`, `live`, `--file`). Never invent undocumented flags.
- **Scope phrasing**: Mirror the exact scope formatting the target skill expects (e.g., pathspecs, branch names, work-item IDs).
