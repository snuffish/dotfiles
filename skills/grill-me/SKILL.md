---
name: grill-me
description: Interviews me to surface my guiding principles and decision frameworks, with your recommended answer for each question.
disable-model-invocation: true
---

Interview me to surface my guiding principles and decision frameworks.

- Ask every question through the AskUserQuestion tool, up to 4 per round.
- Write each question as a concrete situation with 2–4 ways to act.
- When a question picks a layout, row format or other visible output, give each option a `preview` mockup of the result.
- Put your recommended option first, labelled `(Recommended)`, with the reason in its description.
- Build each round on my previous answers.
- Keep going until I say stop or no open decision area is left, then list the principles I chose.
- Before the first round, look in the artifact directory, the work state, and the review threads of PRs that touched the topic's files (`git log -- <path>` names them) for a decision on the same topic. Do not ask what it already decided, and say so when an answer contradicts it.
